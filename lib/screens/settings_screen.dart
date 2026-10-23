import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../utils/keys.dart';
import 'profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relays = ref.watch(relaysProvider);
    final themeMode = ref.watch(themeModeProvider);
    final myProfile = ref.watch(myProfileProvider);
    final myPub = ref.watch(myPubkeyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile entry
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: myPub.when(
                data: (pk) => GradientAvatar(
                  pubkey: pk,
                  displayName: myProfile.nickname ?? 'Me',
                  imagePath: myProfile.avatarPath,
                  size: 48,
                ),
                loading: () => const CircleAvatar(radius: 24),
                error: (_, __) => const CircleAvatar(radius: 24),
              ),
              title: Text(myProfile.nickname ?? 'Me'),
              subtitle: myPub.when(
                data: (pk) => Text(
                    '${NostrKeys.encodeNpub(pk).substring(0, 16)}…'),
                loading: () => const Text(''),
                error: (_, __) => const Text(''),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          ),
          const SizedBox(height: 20),
          Text('Appearance', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).set(v!),
                  title: const Text('Follow system'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).set(v!),
                  title: const Text('Light'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).set(v!),
                  title: const Text('Dark'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Relays', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final r in relays)
                  SwitchListTile(
                    secondary: _StatusDot(status: r.status),
                    title: Text(r.url.replaceFirst('wss://', '')),
                    subtitle: Text(r.status),
                    value: r.enabled,
                    onChanged: (v) =>
                        ref.read(relaysProvider.notifier).setEnabled(r.url, v),
                  ),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('Add relay'),
                  onTap: () => _showAddRelay(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Security', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup_rounded),
                  title: const Text('Backup private key'),
                  onTap: () => _showBackup(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('About'),
                  subtitle: const Text('Nostra v1.0.0'),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRelay(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add relay'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'wss://...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final s = ctrl.text.trim();
              if (s.startsWith('wss://')) {
                ref.read(relaysProvider.notifier).add(s);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showBackup(BuildContext context, WidgetRef ref) async {
    final nsec = await ref.read(identityProvider).exportNsec();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your private key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Write this down. It cannot be recovered.',
                style: TextStyle(color: Colors.orange)),
            const SizedBox(height: 12),
            SelectableText(nsec),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: nsec));
              Navigator.pop(ctx);
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  Color get color => switch (status) {
        'connected' => Colors.green,
        'connecting' => Colors.orange,
        'error' => Colors.red,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
