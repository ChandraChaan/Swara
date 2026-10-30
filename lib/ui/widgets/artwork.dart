import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Resolves an artwork reference (`http…`, `asset:///…` or a file path) to an
/// image provider.
ImageProvider? artworkProvider(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return CachedNetworkImageProvider(url);
  if (url.startsWith('asset:///')) {
    return AssetImage(url.substring('asset:///'.length));
  }
  return FileImage(File(url));
}

class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.url,
    this.size,
    this.radius = 8,
    this.seed = '',
    this.icon = Icons.music_note_rounded,
  });

  final String? url;
  final double? size;
  final double radius;

  /// Picks the placeholder gradient so items without artwork still differ.
  final String seed;
  final IconData icon;

  static const _gradients = [
    [Color(0xFFFF6B35), Color(0xFFD7263D)],
    [Color(0xFF7C4DFF), Color(0xFF00B8D4)],
    [Color(0xFF1DB954), Color(0xFF0B6E4F)],
    [Color(0xFFE91E63), Color(0xFFFF9800)],
    [Color(0xFF3949AB), Color(0xFF8E24AA)],
  ];

  Widget _placeholder() {
    final colors = _gradients[seed.hashCode.abs() % _gradients.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.9),
          size: (size ?? 120) * 0.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = artworkProvider(url);
    Widget child;
    if (provider == null) {
      child = _placeholder();
    } else if (provider is CachedNetworkImageProvider) {
      child = CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => _placeholder(),
        errorWidget: (_, _, _) => _placeholder(),
      );
    } else {
      child = Image(
        image: provider,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}
