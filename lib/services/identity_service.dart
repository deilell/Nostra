import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/keys.dart';

class IdentityService {
  static const _kPriv = 'nsec_hex';
  final FlutterSecureStorage _store;

  IdentityService()
      : _store = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock,
          ),
        );

  Future<bool> hasIdentity() async =>
      (await _store.read(key: _kPriv)) != null;

  Future<String?> get privKey async => _store.read(key: _kPriv);

  Future<String> get pubKey async {
    final p = await privKey;
    if (p == null) throw StateError('No identity');
    return NostrKeys.derivePublicKeyHex(p);
  }

  /// Generate a new identity, store it, return nsec for backup.
  Future<String> generateNew() async {
    final priv = NostrKeys.generatePrivateKeyHex();
    await _store.write(key: _kPriv, value: priv);
    return NostrKeys.encodeNsec(priv);
  }

  /// Import from nsec bech32 or raw hex.
  Future<void> importFromNsec(String input) async {
    String priv;
    final s = input.trim();
    if (s.startsWith('nsec1')) {
      priv = NostrKeys.decodeNsec(s);
    } else if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(s)) {
      priv = s.toLowerCase();
    } else {
      throw ArgumentError('Not a valid nsec or 64-hex private key');
    }
    // validate by deriving pubkey
    NostrKeys.derivePublicKeyHex(priv);
    await _store.write(key: _kPriv, value: priv);
  }

  Future<String> exportNsec() async {
    final p = await privKey;
    if (p == null) throw StateError('No identity');
    return NostrKeys.encodeNsec(p);
  }

  Future<void> wipe() async => _store.delete(key: _kPriv);
}