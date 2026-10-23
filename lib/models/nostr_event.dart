import 'dart:convert';
import '../utils/keys.dart';

/// NIP-01 event model.
class NostrEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;

  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
  });

  static List<int> serialize({
    required String pubkey,
    required int createdAt,
    required int kind,
    required List<List<String>> tags,
    required String content,
  }) {
    final json = jsonEncode([0, pubkey, createdAt, kind, tags, content]);
    return utf8.encode(json);
  }

  static NostrEvent buildAndSign({
    required String privkey,
    required int kind,
    required List<List<String>> tags,
    required String content,
    int? createdAt,
  }) {
    final pubkey = NostrKeys.derivePublicKeyHex(privkey);
    final ts = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final serialized = serialize(
      pubkey: pubkey,
      createdAt: ts,
      kind: kind,
      tags: tags,
      content: content,
    );
    final id = NostrKeys.eventId(serialized);
    final sig = NostrKeys.sign(privkey, id);
    return NostrEvent(
      id: id,
      pubkey: pubkey,
      createdAt: ts,
      kind: kind,
      tags: tags,
      content: content,
      sig: sig,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig,
      };

  static NostrEvent fromJson(Map<String, dynamic> j) => NostrEvent(
        id: j['id'] as String,
        pubkey: j['pubkey'] as String,
        createdAt: j['created_at'] as int,
        kind: j['kind'] as int,
        tags: (j['tags'] as List).map((e) => List<String>.from(e)).toList(),
        content: j['content'] as String,
        sig: j['sig'] as String,
      );

  /// Get the `p` tag pubkeys (for DMs).
  List<String> get pTags =>
      tags.where((t) => t.isNotEmpty && t[0] == 'p').map((t) => t[1]).toList();

  /// Get the `e` tag event id (reply root).
  String? get eTag => tags
      .where((t) => t.isNotEmpty && t[0] == 'e')
      .map((t) => t[1])
      .cast<String?>()
      .firstWhere((_) => true, orElse: () => null);
}
