import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../state/providers.dart';
import '../utils/keys.dart';
import 'home_screen.dart';

class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen> {
  String? _npub;
  String? _nsec;
  bool _busy = false;
  bool _showBackup = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final nsec = await ref.read(identityProvider).generateNew();
      final pub = await ref.read(identityProvider).pubKey;
      setState(() {
        _nsec = nsec;
        _npub = NostrKeys.encodeNpub(pub);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import private key'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Paste nsec1... or 64-hex private key',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await ref.read(identityProvider).importFromNsec(ctrl.text);
      final pub = await ref.read(identityProvider).pubKey;
      setState(() {
        _npub = NostrKeys.encodeNpub(pub);
        _nsec = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  void _enterApp() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => const HomeScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_npub == null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D9CDB), Color(0xFF4FACFE)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Welcome to Nostra',
                    style: theme.textTheme.displayLarge, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'No account. No phone number.\nYour identity is a keypair only you hold.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                _BigButton(
                  icon: Icons.bolt_rounded,
                  title: 'Generate new identity',
                  subtitle: 'Create a fresh keypair',
                  onTap: _busy ? null : _generate,
                ),
                const SizedBox(height: 12),
                _BigButton(
                  icon: Icons.key_rounded,
                  title: 'Import private key',
                  subtitle: 'Restore from nsec backup',
                  onTap: _busy ? null : _import,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    // Show npub + QR
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your identity'),
        actions: [
          TextButton(onPressed: _enterApp, child: const Text('Continue')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _npub!,
                  size: 220,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Theme.of(context).textTheme.bodyMedium!.color!,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Your public key (npub)', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _npub!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _npub!));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('npub copied')));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_nsec != null && !_showBackup)
              OutlinedButton.icon(
                icon: const Icon(Icons.backup_rounded),
                label: const Text('Backup private key'),
                onPressed: () => setState(() => _showBackup = true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            if (_showBackup)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Text('Write this down. It is the only way to recover.',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 12),
                    SelectableText(_nsec!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _nsec!));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('nsec copied')));
                        },
                        child: const Text('Copy nsec'),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _enterApp,
              child: const Text('Enter Nostra'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _BigButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D9CDB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF2D9CDB)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
