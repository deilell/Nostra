import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../state/providers.dart';
import '../widgets/avatar.dart';
import '../utils/keys.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameCtrl;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    final np = ref.read(myProfileProvider);
    _nameCtrl = TextEditingController(text: np.nickname ?? '');
    _charCount = _nameCtrl.text.length;
    _nameCtrl.addListener(() {
      if (mounted) setState(() => _charCount = _nameCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final n = _nameCtrl.text.trim();
    if (n.isEmpty || n.length > 32) return;
    await ref.read(myProfileProvider.notifier).setNickname(n);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nickname saved')));
    }
  }

  Future<void> _pickAvatar(ImageSource src) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: src);
    if (xfile == null) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropScreen(imagePath: xfile.path),
      ),
    );
  }

  void _showAvatarSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remove avatar'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(myProfileProvider.notifier).setAvatar(null);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myPub = ref.watch(myPubkeyProvider);
    final myProfile = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: myPub.when(
        data: (pk) {
          final npub = NostrKeys.encodeNpub(pk);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showAvatarSheet,
                  child: Stack(
                    children: [
                      GradientAvatar(
                        pubkey: pk,
                        displayName: myProfile.nickname ?? '?',
                        imagePath: myProfile.avatarPath,
                        size: 110,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('Nickname', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                maxLength: 32,
                decoration: InputDecoration(
                  hintText: pk.substring(0, 8),
                  counterText: '$_charCount/32',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    _charCount == 0 || _charCount > 32 ? null : _saveName,
                child: const Text('Save nickname'),
              ),
              const SizedBox(height: 32),
              Text('Public key', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(npub,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class CropScreen extends ConsumerStatefulWidget {
  final String imagePath;
  const CropScreen({super.key, required this.imagePath});

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  final _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop avatar'),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            child: _cropping
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Use'),
          ),
        ],
      ),
      body: Crop(
        image: File(widget.imagePath).readAsBytesSync(),
        controller: _controller,
        aspectRatio: 1,
        withCircleUi: true,
        onCropped: (result) async {
          final bytes = result;
          final dir = await getApplicationDocumentsDirectory();
          final path = p.join(dir.path, 'avatar.png');
          await File(path).writeAsBytes(bytes);
          if (!mounted) return;
          await ref.read(myProfileProvider.notifier).setAvatar(path);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Avatar saved')));
          }
        },
      ),
    );
  }
}