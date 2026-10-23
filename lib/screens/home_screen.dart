import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../models/chat_models.dart';
import '../models/nostr_event.dart';
import '../utils/keys.dart';
import '../widgets/avatar.dart';
import 'chat_screen.dart';
import 'add_friend_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription? _evSub;

  @override
  void initState() {
    super.initState();
    _startNostr();
  }

  Future<void> _startNostr() async {
    final nostr = ref.read(nostrProvider);
    final identity = ref.read(identityProvider);
    final storage = ref.read(storageProvider);
    final myPriv = await identity.privKey;
    final myPub = await identity.pubKey;

    nostr.onEvent = (NostrEvent ev, String _) async {
      // only kind 4 DMs
      if (ev.kind != 4) return;
      // determine the other party
      String other;
      bool incoming;
      if (ev.pubkey == myPub) {
        // our own outgoing event
        other = ev.pTags.isNotEmpty ? ev.pTags.first : '';
        incoming = false;
      } else {
        other = ev.pubkey;
        incoming = true;
      }
      if (other.isEmpty) return;
      // decrypt
      String plain;
      try {
        final priv = myPriv!;
        plain = NostrKeys.nip04Decrypt(priv, other, ev.content);
      } catch (e) {
        plain = '[undecryptable]';
      }
      final msg = ChatMessage(
        id: ev.id,
        remotePubkey: other,
        content: plain,
        createdAt: ev.createdAt,
        incoming: incoming,
        status: 'sent',
      );
      await storage.insertMessage(msg);
      // ensure contact exists
      final contacts = await storage.getContacts();
      if (!contacts.any((c) => c.pubkey == other)) {
        await storage.upsertContact(Contact(
          pubkey: other,
          addedAt: DateTime.now(),
        ));
      }
      ref.invalidate(conversationsProvider);
      ref.invalidate(messagesProvider(other));
    };
    nostr.onRelayStatus = (url, status) {
      ref.read(relaysProvider.notifier).updateStatus(url, status);
    };
    await nostr.start();
  }

  @override
  void dispose() {
    _evSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convs = ref.watch(conversationsProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(conversationsProvider);
            await ref.read(conversationsProvider.future);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('Messages',
                              style:
                                  Theme.of(context).textTheme.displayLarge)),
                      IconButton(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddFriendScreen()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              convs.when(
                data: (list) {
                  if (list.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _ConversationTile(contact: list[i]),
                      childCount: list.length,
                    ),
                  );
                },
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Contact contact;
  const _ConversationTile({required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastMessageProvider(contact.pubkey));
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(contact: contact),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            GradientAvatar(
              pubkey: contact.pubkey,
              displayName: contact.displayName,
              imagePath: contact.avatarPath,
              size: 52,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.displayName,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  last.when(
                    data: (m) => Text(
                      m?.content ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                last.when(
                  data: (m) => m == null
                      ? const SizedBox.shrink()
                      : Text(_timeAgo(m.createdAt),
                          style: Theme.of(context).textTheme.labelSmall),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2D9CDB).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined,
                size: 48, color: Color(0xFF2D9CDB)),
          ),
          const SizedBox(height: 20),
          Text('No conversations yet',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Add a friend and start chatting',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _timeAgo(int unix) {
  final dt = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dt.month}/${dt.day}';
}
