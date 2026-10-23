import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../services/identity_service.dart';
import '../services/nostr_service.dart';
import '../models/chat_models.dart';

// ---- core services ----
final storageProvider = Provider<StorageService>((ref) => StorageService());
final identityProvider = Provider<IdentityService>((ref) => IdentityService());
final nostrProvider = Provider<NostrService>((ref) => NostrService(ref.read(storageProvider), ref.read(identityProvider)));

// ---- app bootstrap ----
final bootProvider = FutureProvider<bool>((ref) async {
  final id = ref.read(identityProvider);
  final has = await id.hasIdentity();
  return has;
});

// ---- my pubkey ----
final myPubkeyProvider = FutureProvider<String>((ref) async {
  final id = ref.read(identityProvider);
  return id.pubKey;
});

// ---- theme mode ----
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }
  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getString('theme_mode') ?? 'system';
    state = switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode m) async {
    state = m;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('theme_mode', m.name);
  }
}

// ---- contacts ----
final contactsProvider =
    StateNotifierProvider<ContactsNotifier, AsyncValue<List<Contact>>>((ref) {
  return ContactsNotifier(ref.read(storageProvider));
});

class ContactsNotifier extends StateNotifier<AsyncValue<List<Contact>>> {
  final StorageService _s;
  ContactsNotifier(this._s) : super(const AsyncValue.loading()) {
    reload();
  }

  Future<void> reload() async {
    state = AsyncValue.data(await _s.getContacts());
  }

  Future<void> add(String pubkeyHex, {String? nickname}) async {
    final c = Contact(
      pubkey: pubkeyHex,
      nickname: nickname,
      addedAt: DateTime.now(),
    );
    await _s.upsertContact(c);
    await reload();
  }

  Future<void> updateNickname(String pubkey, String name) async {
    final list = state.valueOrNull ?? [];
    final idx = list.indexWhere((c) => c.pubkey == pubkey);
    if (idx < 0) return;
    final c = list[idx]..nickname = name;
    await _s.upsertContact(c);
    await reload();
  }

  Future<void> updateAvatar(String pubkey, String? path) async {
    final list = state.valueOrNull ?? [];
    final idx = list.indexWhere((c) => c.pubkey == pubkey);
    if (idx < 0) return;
    final c = list[idx]..avatarPath = path;
    await _s.upsertContact(c);
    await reload();
  }

  Future<void> remove(String pubkey) async {
    await _s.deleteContact(pubkey);
    await reload();
  }
}

// ---- my profile (nickname/avatar for self) ----
final myProfileProvider =
    StateNotifierProvider<MyProfileNotifier, ({String? nickname, String? avatarPath})>((ref) {
  return MyProfileNotifier(ref.read(storageProvider));
});

class MyProfileNotifier extends StateNotifier<({String? nickname, String? avatarPath})> {
  final StorageService _s;
  MyProfileNotifier(this._s) : super((nickname: null, avatarPath: null)) {
    _load();
  }
  Future<void> _load() async {
    final n = await _s.getProfile('my_nickname');
    final a = await _s.getProfile('my_avatar');
    state = (nickname: n, avatarPath: a);
  }
  Future<void> setNickname(String n) async {
    await _s.setProfile('my_nickname', n);
    state = (nickname: n, avatarPath: state.avatarPath);
  }
  Future<void> setAvatar(String? p) async {
    await _s.setProfile('my_avatar', p);
    state = (nickname: state.nickname, avatarPath: p);
  }
}

// ---- relays ----
final relaysProvider =
    StateNotifierProvider<RelaysNotifier, List<Relay>>((ref) {
  return RelaysNotifier(ref.read(storageProvider), ref.read(nostrProvider));
});

class RelaysNotifier extends StateNotifier<List<Relay>> {
  final StorageService _s;
  final NostrService _n;
  RelaysNotifier(this._s, this._n) : super([]) {
    _load();
  }
  Future<void> _load() async {
    state = await _s.getRelays();
  }

  void updateStatus(String url, String status) {
    state = [
      for (final r in state)
        if (r.url == url) Relay(url: r.url, enabled: r.enabled, status: status) else r,
    ];
  }

  Future<void> add(String url) async {
    await _n.addRelay(url);
    await _load();
  }
  Future<void> remove(String url) async {
    await _n.removeRelay(url);
    await _load();
  }
  Future<void> setEnabled(String url, bool enabled) async {
    await _n.setRelayEnabled(url, enabled);
    await _load();
  }
}

// ---- conversations (session list) ----
final conversationsProvider =
    FutureProvider.autoDispose<List<Contact>>((ref) async {
  final s = ref.read(storageProvider);
  return s.getConversations();
});

// ---- messages for a chat ----
final messagesProvider = FutureProvider.family
    .autoDispose<List<ChatMessage>, String>((ref, remotePubkey) async {
  final s = ref.read(storageProvider);
  return s.getMessages(remotePubkey);
});

// ---- last message helper ----
final lastMessageProvider = FutureProvider.family
    .autoDispose<ChatMessage?, String>((ref, remotePubkey) async {
  final s = ref.read(storageProvider);
  return s.lastMessage(remotePubkey);
});
