import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_models.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Contact contact;
  const ChatScreen({super.key, required this.contact});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() => _sending = true);

    final identity = ref.read(identityProvider);
    final storage = ref.read(storageProvider);
    final nostr = ref.read(nostrProvider);
    final priv = await identity.privKey;

    // optimistic local insert
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tempId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final local = ChatMessage(
      id: tempId,
      remotePubkey: widget.contact.pubkey,
      content: text,
      createdAt: now,
      incoming: false,
      status: 'sending',
    );
    await storage.insertMessage(local);
    ref.invalidate(messagesProvider(widget.contact.pubkey));

    try {
      final realId = await nostr.publishDM(
        privkey: priv!,
        recipientPub: widget.contact.pubkey,
        plaintext: text,
      );
      await storage.insertMessage(ChatMessage(
        id: realId,
        remotePubkey: widget.contact.pubkey,
        content: text,
        createdAt: now,
        incoming: false,
        status: 'sent',
      ));
      await storage.updateMessageStatus(tempId, 'sent');
    } catch (_) {
      await storage.updateMessageStatus(tempId, 'failed');
    }
    ref.invalidate(messagesProvider(widget.contact.pubkey));
    ref.invalidate(conversationsProvider);
    setState(() => _sending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(messagesProvider(widget.contact.pubkey));
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            GradientAvatar(
              pubkey: widget.contact.pubkey,
              displayName: widget.contact.displayName,
              imagePath: widget.contact.avatarPath,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.contact.displayName,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('connecting...',
                          style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: msgs.when(
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text('Say hello to ${widget.contact.displayName}',
                        style: Theme.of(context).textTheme.bodySmall),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) {
                    final m = list[i];
                    final showTime = i == 0 ||
                        list[i - 1].createdAt - m.createdAt > 3600;
                    return _MessageBubble(
                      message: m,
                      showTime: showTime,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface2
                      : AppColors.lightSurface2,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTime;
  const _MessageBubble({required this.message, required this.showTime});

  @override
  Widget build(BuildContext context) {
    final isMe = !message.incoming;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isMe
        ? AppColors.primary
        : (isDark ? AppColors.darkBubbleOther : AppColors.lightBubbleOther);
    final fg = isMe ? Colors.white : Theme.of(context).textTheme.bodyMedium!.color!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showTime)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(_fmtTime(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall),
            ),
          GestureDetector(
            onLongPress: () => showModalBottomSheet(
              context: context,
              builder: (ctx) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.copy_rounded),
                      title: const Text('Copy'),
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: message.content));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')));
                      },
                    ),
                  ],
                ),
              ),
            ),
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.content,
                      style: TextStyle(color: fg, fontSize: 15, height: 1.3)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 10, color: fg.withOpacity(0.6)),
                      const SizedBox(width: 3),
                      Text(_fmtTime(message.createdAt),
                          style: TextStyle(
                              fontSize: 10, color: fg.withOpacity(0.6))),
                      const SizedBox(width: 4),
                      if (isMe) _statusIcon(message.status, fg),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(String s, Color c) {
    switch (s) {
      case 'sending':
        return Icon(Icons.access_time, size: 11, color: c.withOpacity(0.6));
      case 'failed':
        return Icon(Icons.error_outline, size: 12, color: Colors.red.shade300);
      default:
        return Icon(Icons.check, size: 12, color: c.withOpacity(0.6));
    }
  }
}

String _fmtTime(int unix) {
  final dt = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
