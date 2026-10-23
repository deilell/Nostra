import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_models.dart';

/// Local SQLite storage for contacts, messages, relays, profile.
class StorageService {
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'nostra.db');
    _db = await openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute('''CREATE TABLE contacts(
        pubkey TEXT PRIMARY KEY,
        nickname TEXT,
        avatar_path TEXT,
        added_at INTEGER NOT NULL
      )''');
      await d.execute('''CREATE TABLE messages(
        id TEXT PRIMARY KEY,
        remote_pubkey TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        incoming INTEGER NOT NULL,
        status TEXT NOT NULL
      )''');
      await d.execute('CREATE INDEX idx_msg_remote ON messages(remote_pubkey, created_at)');
      await d.execute('''CREATE TABLE relays(
        url TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL
      )''');
      await d.execute('''CREATE TABLE profile(
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    });
    return _db!;
  }

  // ---- profile (local nickname) ----
  Future<void> setProfile(String key, String? value) async {
    final d = await db;
    await d.insert('profile', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getProfile(String key) async {
    final d = await db;
    final rows = await d.query('profile', where: 'key=?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  // ---- contacts ----
  Future<List<Contact>> getContacts() async {
    final d = await db;
    final rows = await d.query('contacts', orderBy: 'added_at DESC');
    return rows.map((r) => Contact.fromMap(r)).toList();
  }

  Future<void> upsertContact(Contact c) async {
    final d = await db;
    await d.insert('contacts', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteContact(String pubkey) async {
    final d = await db;
    await d.delete('contacts', where: 'pubkey=?', whereArgs: [pubkey]);
  }

  // ---- messages ----
  Future<List<ChatMessage>> getMessages(String remotePubkey, {int limit = 300}) async {
    final d = await db;
    final rows = await d.query('messages',
        where: 'remote_pubkey=?',
        whereArgs: [remotePubkey],
        orderBy: 'created_at ASC',
        limit: limit);
    return rows.map((r) => ChatMessage.fromMap(r)).toList();
  }

  Future<List<Contact>> getConversations() async {
    // Distinct remote pubkeys with last message.
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT remote_pubkey, MAX(created_at) as last_ts
      FROM messages GROUP BY remote_pubkey ORDER BY last_ts DESC
    ''');
    final result = <Contact>[];
    for (final r in rows) {
      final pk = r['remote_pubkey'] as String;
      final cRows = await d.query('contacts', where: 'pubkey=?', whereArgs: [pk]);
      Contact c;
      if (cRows.isNotEmpty) {
        c = Contact.fromMap(cRows.first);
      } else {
        c = Contact(pubkey: pk, addedAt: DateTime.now());
      }
      result.add(c);
    }
    return result;
  }

  Future<ChatMessage?> lastMessage(String remotePubkey) async {
    final d = await db;
    final rows = await d.query('messages',
        where: 'remote_pubkey=?',
        whereArgs: [remotePubkey],
        orderBy: 'created_at DESC',
        limit: 1);
    return rows.isEmpty ? null : ChatMessage.fromMap(rows.first);
  }

  Future<void> insertMessage(ChatMessage m) async {
    final d = await db;
    await d.insert('messages', m.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> updateMessageStatus(String id, String status) async {
    final d = await db;
    await d.update('messages', {'status': status},
        where: 'id=?', whereArgs: [id]);
  }

  // ---- relays ----
  static const defaultRelays = [
    'wss://relay.damus.io',
    'wss://relay.nostr.band',
    'wss://nos.lol',
    'wss://relay.primal.net',
  ];

  Future<List<Relay>> getRelays() async {
    final d = await db;
    final rows = await d.query('relays');
    if (rows.isEmpty) {
      for (final r in defaultRelays) {
        await d.insert('relays', {'url': r, 'enabled': 1});
      }
      return defaultRelays.map((u) => Relay(url: u)).toList();
    }
    return rows.map((r) => Relay.fromMap(r)).toList();
  }

  Future<void> addRelay(String url) async {
    final d = await db;
    await d.insert('relays', {'url': url, 'enabled': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeRelay(String url) async {
    final d = await db;
    await d.delete('relays', where: 'url=?', whereArgs: [url]);
  }

  Future<void> setRelayEnabled(String url, bool enabled) async {
    final d = await db;
    await d.update('relays', {'enabled': enabled ? 1 : 0},
        where: 'url=?', whereArgs: [url]);
  }
}
