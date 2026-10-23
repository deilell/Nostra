/// Contact = a Nostr pubkey we've added.
class Contact {
  final String pubkey; // 64-hex
  String? nickname; // local display name
  String? avatarPath; // local file path
  final DateTime addedAt;

  Contact({
    required this.pubkey,
    this.nickname,
    this.avatarPath,
    required this.addedAt,
  });

  /// Short hex form for display: "abcd…1234"
  String get shortId =>
      '${pubkey.substring(0, 6)}…${pubkey.substring(pubkey.length - 6)}';

  String get displayName =>
      (nickname != null && nickname!.trim().isNotEmpty) ? nickname!.trim() : shortId;

  Map<String, dynamic> toMap() => {
        'pubkey': pubkey,
        'nickname': nickname,
        'avatar_path': avatarPath,
        'added_at': addedAt.millisecondsSinceEpoch ~/ 1000,
      };

  static Contact fromMap(Map<String, dynamic> m) => Contact(
        pubkey: m['pubkey'] as String,
        nickname: m['nickname'] as String?,
        avatarPath: m['avatar_path'] as String?,
        addedAt:
            DateTime.fromMillisecondsSinceEpoch((m['added_at'] as int) * 1000),
      );
}

/// A chat message stored locally.
class ChatMessage {
  final String id; // event id
  final String remotePubkey;
  final String content; // decrypted plaintext
  final int createdAt; // unix seconds
  final bool incoming;
  String status; // sending / sent / failed

  ChatMessage({
    required this.id,
    required this.remotePubkey,
    required this.content,
    required this.createdAt,
    required this.incoming,
    this.status = 'sent',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'remote_pubkey': remotePubkey,
        'content': content,
        'created_at': createdAt,
        'incoming': incoming ? 1 : 0,
        'status': status,
      };

  static ChatMessage fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        remotePubkey: m['remote_pubkey'] as String,
        content: m['content'] as String,
        createdAt: m['created_at'] as int,
        incoming: (m['incoming'] as int) == 1,
        status: m['status'] as String? ?? 'sent',
      );
}

/// A relay URL + connection state.
class Relay {
  final String url;
  bool enabled;
  String status; // disconnected / connecting / connected / error

  Relay(
      {required this.url, this.enabled = true, this.status = 'disconnected'});

  Map<String, dynamic> toMap() => {'url': url, 'enabled': enabled ? 1 : 0};

  static Relay fromMap(Map<String, dynamic> m) => Relay(
      url: m['url'] as String, enabled: (m['enabled'] as int) == 1);
}
