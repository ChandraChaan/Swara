import 'package:flutter/material.dart';

import 'artwork.dart';

final _cache = <String, Color>{};

/// Extracts a dominant colour from the artwork, the way Spotify tints the
/// player background, and rebuilds when it is known.
class ArtworkColorBuilder extends StatefulWidget {
  const ArtworkColorBuilder({
    super.key,
    required this.artworkUrl,
    required this.fallback,
    required this.builder,
  });

  final String? artworkUrl;
  final Color fallback;
  final Widget Function(BuildContext context, Color color) builder;

  @override
  State<ArtworkColorBuilder> createState() => _ArtworkColorBuilderState();
}

class _ArtworkColorBuilderState extends State<ArtworkColorBuilder> {
  Color? _color;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(ArtworkColorBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkUrl != widget.artworkUrl) _resolve();
  }

  Future<void> _resolve() async {
    final url = widget.artworkUrl;
    final provider = artworkProvider(url);
    if (url == null || provider == null) {
      setState(() => _color = null);
      return;
    }
    final cached = _cache[url];
    if (cached != null) {
      setState(() => _color = cached);
      return;
    }
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: ResizeImage(provider, width: 64, height: 64),
        brightness: Brightness.dark,
      );
      final color = scheme.primary;
      _cache[url] = color;
      if (mounted && widget.artworkUrl == url) setState(() => _color = color);
    } catch (_) {
      if (mounted) setState(() => _color = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _color ?? widget.fallback),
      duration: const Duration(milliseconds: 500),
      builder: (context, color, _) =>
          widget.builder(context, color ?? widget.fallback),
    );
  }
}
