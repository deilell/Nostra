import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../state/providers.dart';
import '../utils/keys.dart';

class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen>
    with SingleTickerProviderStateMixin {
  final _input = TextEditingController();
  String? _myNpub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pub = await ref.read(identityProvider).pubKey;
    if (mounted) setState(() => _myNpub = NostrKeys.encodeNpub(pub));
  }

  Future<void> _addFromInput() async {
    final s = _input.text.trim();
    if (s.isEmpty) return;
    try {
      final hex = s.startsWith('npub1') ? NostrKeys.decodeNpub(s) : s;
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hex)) {
        throw ArgumentError('Invalid npub');
      }
      await ref.read(contactsProvider.notifier).add(hex.toLowerCase());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Friend added')));
        _input.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Scan npub QR')),
          body: MobileScanner(
            onDetect: (cap) {
              final code = cap.barcodes.first.rawValue;
              if (code != null) {
                Navigator.pop(context);
                _input.text = code;
                _addFromInput();
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add friend')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Your QR code', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_myNpub != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: QrImageView(
                  data: _myNpub!,
                  size: 200,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Theme.of(context).textTheme.bodyMedium!.color!,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: SelectableText(
              _myNpub ?? '',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 24),
          Text('Paste npub', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  decoration: const InputDecoration(
                    hintText: 'npub1...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addFromInput,
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan QR code'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }
}