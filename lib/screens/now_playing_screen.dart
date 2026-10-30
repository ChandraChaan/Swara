import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../player/player_controller.dart';
import '../theme.dart';
import '../widgets/track_widgets.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const NowPlayingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (track == null) {
      return const Scaffold(body: Center(child: Text('Nothing is playing')));
    }

    final maxMs = player.duration.inMilliseconds.toDouble();
    final posMs = player.position.inMilliseconds.toDouble().clamp(
      0.0,
      maxMs <= 0 ? 0.0 : maxMs,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(track.album, style: textTheme.titleSmall),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final coverSize = (constraints.maxWidth - 48)
                .clamp(160.0, 420.0)
                .toDouble();
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Hero(
                    tag: 'cover',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: CoverArt(
                        track: track,
                        size: coverSize,
                        radius: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(track.artist, style: textTheme.bodyLarge),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: player.isFavourite(track)
                            ? 'Remove from favourites'
                            : 'Add to favourites',
                        iconSize: 28,
                        icon: Icon(
                          player.isFavourite(track)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: player.isFavourite(track)
                              ? SwaraTheme.accent
                              : null,
                        ),
                        onPressed: () => player.toggleFavourite(track),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.music_note,
                        label: 'Raga ${track.raga}',
                      ),
                      _InfoChip(
                        icon: Icons.piano,
                        label: track.instrumentLabel,
                      ),
                      _InfoChip(
                        icon: Icons.av_timer,
                        label: '${track.tala} · ${track.bpm} bpm',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Slider(
                    value: posMs,
                    max: maxMs <= 0 ? 1 : maxMs,
                    onChanged: maxMs <= 0
                        ? null
                        : (v) => player.seek(Duration(milliseconds: v.round())),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(player.position),
                        style: textTheme.bodySmall,
                      ),
                      Text(
                        formatDuration(player.duration),
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Shuffle',
                        icon: Icon(
                          Icons.shuffle,
                          color: player.shuffle
                              ? SwaraTheme.accent
                              : scheme.onSurfaceVariant,
                        ),
                        onPressed: player.toggleShuffle,
                      ),
                      IconButton(
                        tooltip: 'Previous',
                        iconSize: 40,
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: player.previous,
                      ),
                      DecoratedBox(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SwaraTheme.brandGradient,
                        ),
                        child: IconButton(
                          tooltip: player.isPlaying ? 'Pause' : 'Play',
                          iconSize: 48,
                          color: Colors.white,
                          padding: const EdgeInsets.all(14),
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          onPressed: player.togglePlay,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next',
                        iconSize: 40,
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: player.next,
                      ),
                      IconButton(
                        tooltip: switch (player.repeat) {
                          LoopMode.off => 'Repeat off',
                          LoopMode.all => 'Repeat all',
                          LoopMode.one => 'Repeat one',
                        },
                        icon: Icon(
                          player.repeat == LoopMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: player.repeat == LoopMode.off
                              ? scheme.onSurfaceVariant
                              : SwaraTheme.accent,
                        ),
                        onPressed: player.cycleRepeat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
