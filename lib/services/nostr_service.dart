import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/nostr_event.dart';
import '../models/chat_models.dart';
import '../utils/keys.dart';
import 'storage_service.dart';
import 'identity_service.dart';

typedef EventCallback = void Function(NostrEvent e, String relayUrl);

/// Manages WebSocket connections to Nostr relays, subscriptions and publishing.
class NostrService {
  final StorageService _storage;
  final IdentityService _identity;
  NostrService(this._storage, this._identity);

  final Map<String, WebSocketChannel> _channels = {};
  final Map<String, Relay> _relayState = {};
  final Set<StreamSubscription> _subs = {};
  final Map<String, String> _subIdByRelay = {};

  EventCallback? onEvent;
  void Function(String relayUrl, String status)? onRelayStatus;

  bool _started = false;
  String? _myPubkey;

  List<Relay> get relays => _relayState.values.toList();

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _myPubkey = await _identity.pubKey;
    final list = await _storage.getRelays();
    for (final r in list) {
      _relayState[r.url] = r;
      if (r.enabled) _connect(r.url);
    }
  }

  void _connect(String url) {
    if (_channels.containsKey(url)) return;
    final state = _relayState[url];
    state?.status = 'connecting';
    onRelayStatus?.call(url, 'connecting');
    try {
      final ch = WebSocketChannel.connect(Uri.parse(url));
      _channels[url] = ch;
      _subs.add(ch.stream.listen(
        (data) => _onData(url, data),
        onError: (_) {
          state?.status = 'error';
          onRelayStatus?.call(url, 'error');
          _channels.remove(url);
        },
        onDone: () {
          state?.status = 'disconnected';
          onRelayStatus?.call(url, 'disconnected');
          _channels.remove(url);
        },
      ));
      // wait for open
      ch.ready.then((_) {
        state?.status = 'connected';
        onRelayStatus?.call(url, 'connected');
        _subscribe(url);
      }).catchError((_) {
        state?.status = 'error';
        onRelayStatus?.call(url, 'error');
      });
    } catch (_) {
      state?.status = 'error';
      onRelayStatus?.call(url, 'error');
    }
  }

  void _subscribe(String url) {
    if (_myPubkey == null) return;
    final subId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    _subIdByRelay[url] = subId;
    final filter = {
      'kinds': [4],
      '#p': [_myPubkey],
      'since': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 86400 * 7,
    };
    final msg = jsonEncode(['REQ', subId, filter]);
    _channels[url]?.sink.add(msg);
  }

  void _onData(String url, dynamic data) {
    try {
      final list = jsonDecode(data as String) as List;
      if (list.isEmpty) return;
      final type = list[0];
      if (type == 'EVENT') {
        final ev = NostrEvent.fromJson(list[2] as Map<String, dynamic>);
        onEvent?.call(ev, url);
      }
    } catch (_) {}
  }

  /// Publish a kind-4 DM to all connected relays.
  Future<String> publishDM({
    required String privkey,
    required String recipientPub,
    required String plaintext,
  }) async {
    final content = NostrKeys.nip04Encrypt(privkey, recipientPub, plaintext);
    final ev = NostrEvent.buildAndSign(
      privkey: privkey,
      kind: 4,
      tags: [
        ['p', recipientPub]
      ],
      content: content,
    );
    final msg = jsonEncode(['EVENT', ev.toJson()]);
    for (final ch in _channels.values) {
      try {
        ch.sink.add(msg);
      } catch (_) {}
    }
    return ev.id;
  }

  Future<void> addRelay(String url) async {
    await _storage.addRelay(url);
    if (!_relayState.containsKey(url)) {
      _relayState[url] = Relay(url: url);
    }
    _connect(url);
  }

  Future<void> removeRelay(String url) async {
    await _storage.removeRelay(url);
    await _channels[url]?.sink.close();
    _channels.remove(url);
    _relayState.remove(url);
  }

  Future<void> setRelayEnabled(String url, bool enabled) async {
    await _storage.setRelayEnabled(url, enabled);
    final r = _relayState[url];
    r?.enabled = enabled;
    if (!enabled) {
      await _channels[url]?.sink.close();
      _channels.remove(url);
      r?.status = 'disconnected';
    } else {
      _connect(url);
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    for (final c in _channels.values) {
      await c.sink.close();
    }
    _channels.clear();
  }
}
