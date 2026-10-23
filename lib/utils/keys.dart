import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:bech32/bech32.dart';
import 'package:hex/hex.dart';

/// secp256k1 key utilities, bech32 npub/nsec, NIP-01 signing, NIP-04 encryption.
class NostrKeys {
  static final ECDomainParameters _params = ECDomainParameters('secp256k1');
  static final Random _rng = Random.secure();

  static String generatePrivateKeyHex() {
    final n = _params.n;
    while (true) {
      final b = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        b[i] = _rng.nextInt(256);
      }
      final v = BigInt.parse(HEX.encode(b), radix: 16);
      if (v > BigInt.zero && v < n) {
        return v.toRadixString(16).padLeft(64, '0');
      }
    }
  }

  static String derivePublicKeyHex(String privateHex) {
    final d = BigInt.parse(privateHex, radix: 16);
    final Q = _params.G! * d;
    return _encodeCompressed(Q!);
  }

  static String _encodeCompressed(ECPoint Q) {
    final x = Q.x!.toBigInteger()!;
    final y = Q.y!.toBigInteger()!;
    final prefix = y.isEven ? 0x02 : 0x03;
    final xB = _bigTo32(x);
    return HEX.encode(Uint8List.fromList([prefix, ...xB]));
  }

  static Uint8List _bigTo32(BigInt v) {
    final s = v.toRadixString(16).padLeft(64, '0');
    return Uint8List.fromList(HEX.decode(s));
  }

  static String encodeNpub(String pubHex) => _encode('npub', pubHex);
  static String encodeNsec(String privHex) => _encode('nsec', privHex);

  static String _encode(String hrp, String hexKey) {
    final data = HEX.decode(hexKey);
    final words = _bits(data, 8, 5, true);
    return Bech32Codec().encode(Bech32(hrp, words), 1000);
  }

  static String decodeNpub(String s) => _decode('npub', s);
  static String decodeNsec(String s) => _decode('nsec', s);

  static String _decode(String expected, String input) {
    final b = Bech32Codec().decode(input.trim(), 1000);
    if (b.hrp != expected) {
      throw ArgumentError('Expected $expected, got ${b.hrp}');
    }
    final data = _bits(b.data, 5, 8, false);
    return HEX.encode(data);
  }

  static List<int> _bits(List<int> data, int from, int to, bool pad) {
    var acc = 0, bits = 0;
    final out = <int>[];
    final maxV = (1 << to) - 1;
    final maxAcc = (1 << (from + to - 1)) - 1;
    for (final v in data) {
      if (v < 0 || (v >> from) != 0) throw ArgumentError('bad bits');
      acc = ((acc << from) | v) & maxAcc;
      bits += from;
      while (bits >= to) {
        bits -= to;
        out.add((acc >> bits) & maxV);
      }
    }
    if (pad) {
      if (bits > 0) out.add((acc << (to - bits)) & maxV);
    } else if (bits >= from || ((acc << (to - bits)) & maxV) != 0) {
      throw ArgumentError('bad padding');
    }
    return out;
  }

  static String eventId(List<int> serialized) =>
      HEX.encode(SHA256Digest().process(Uint8List.fromList(serialized)));

  static String sign(String privHex, String hashHex) {
    final signer = ECDSASigner(SHA256Digest());
    final d = BigInt.parse(privHex, radix: 16);
    final rng = FortunaRandom();
    rng.seed(KeyParameter(Uint8List.fromList(
        List.generate(32, (_) => _rng.nextInt(256)))));
    signer.init(true, PrivateKeyParameter(ECPrivateKey(d, _params)));
    final sig = signer.generateSignature(Uint8List.fromList(HEX.decode(hashHex))) as ECSignature;
    var r = sig.r;
    var s = sig.s;
    final n = _params.n;
    if (s > (n >> 1)) s = n - s;
    return HEX.encode(Uint8List.fromList([..._bigTo32(r), ..._bigTo32(s)]));
  }

  static String nip04Encrypt(String privHex, String theirPubHex, String plain) {
    final shared = _ecdhX(privHex, theirPubHex);
    final key = SHA256Digest().process(shared);
    final iv = Uint8List.fromList(List.generate(16, (_) => _rng.nextInt(256)));
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(true, PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv), null));
    final ct = cipher.process(Uint8List.fromList(utf8.encode(plain)));
    // NIP-04: MAC = HMAC-SHA256(key[16..32], iv || ciphertext)
    final hmac = HMac(SHA256Digest(), 64)
      ..init(KeyParameter(key.sublist(16, 32)));
    final mac = hmac.process(Uint8List.fromList([...iv, ...ct]));
    // NIP-04 payload: base64(ciphertext)?iv=base64(iv)&mac=hex(mac)
    return '${base64.encode(ct)}?iv=${base64.encode(iv)}&mac=${HEX.encode(mac)}';
  }

  static String nip04Decrypt(String privHex, String theirPubHex, String payload) {
    // NIP-04 payload: base64(ciphertext)?iv=base64(iv)&mac=hex(mac)
    final q = payload.split('?iv=');
    if (q.length != 2) throw ArgumentError('bad nip04');
    final rest = q[1].split('&');
    final ct = base64.decode(q[0]);
    final iv = base64.decode(rest[0]);
    final shared = _ecdhX(privHex, theirPubHex);
    final key = SHA256Digest().process(shared);
    // 校验 MAC（若载荷带 mac 字段），防止密文被篡改
    if (rest.length > 1 && rest[1].startsWith('mac=')) {
      final hmac = HMac(SHA256Digest(), 64)
        ..init(KeyParameter(key.sublist(16, 32)));
      final expect = hmac.process(Uint8List.fromList([...iv, ...ct]));
      final got = rest[1].substring(4);
      if (HEX.encode(expect) != got.toLowerCase()) {
        throw ArgumentError('bad mac');
      }
    }
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(false, PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv), null));
    final pt = cipher.process(ct);
    return utf8.decode(pt, allowMalformed: true);
  }

  static Uint8List _ecdhX(String privHex, String theirPubHex) {
    final d = BigInt.parse(privHex, radix: 16);
    final q = _params.curve.decodePoint(HEX.decode(theirPubHex)) as ECPoint;
    final s = q * d;
    return _bigTo32(s!.x!.toBigInteger()!);
  }
}