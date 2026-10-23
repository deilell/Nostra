import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';

/// Deterministic gradient avatar from pubkey hash + optional image.
class GradientAvatar extends StatelessWidget {
  final String pubkey;
  final String? displayName;
  final String? imagePath;
  final double size;
  const GradientAvatar({
    super.key,
    required this.pubkey,
    this.displayName,
    this.imagePath,
    this.size = 48,
  });

  (Color, Color) _gradient(String pubkey) {
    final rng = Random(pubkey.hashCode);
    final palettes = <List<Color>>[
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFF093FB), const Color(0xFFF5576C)],
      [const Color(0xFF4FACFE), const Color(0xFF00F2FE)],
      [const Color(0xFF43E97B), const Color(0xFF38F9D7)],
      [const Color(0xFFFA709A), const Color(0xFFFEE140)],
      [const Color(0xFF30CFD0), const Color(0xFF330867)],
      [const Color(0xFFFF9A44), const Color(0xFFFF5E62)],
      [const Color(0xFFA18CD1), const Color(0xFFFBC2EB)],
    ];
    final p = palettes[rng.nextInt(palettes.length)];
    return (p[0], p[1]);
  }

  String get _initial {
    final n = displayName?.trim() ?? '';
    if (n.isEmpty) return '?';
    return n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (c1, c2) = _gradient(pubkey);
    final hasImage = imagePath != null && File(imagePath!).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
        image: hasImage
            ? DecorationImage(image: FileImage(File(imagePath!)), fit: BoxFit.cover)
            : null,
      ),
      child: hasImage
          ? null
          : Center(
              child: Text(
                _initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}
