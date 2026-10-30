import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../player/player_controller.dart';
import '../screens/now_playing_screen.dart';
import '../theme.dart';

class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.track, this.size, this.radius = 12});

  final Track track;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        track.coverAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// A list row for a track; tapping it plays the track within [queue].
class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.track, required this.queue});

  final Track track;
  final List<Track> queue;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final isCurrent = player.current?.id == track.id;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: CoverArt(track: track, size: 52, radius: 8),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isCurrent ? SwaraTheme.accent : null,
        ),
      ),
      subtitle: Text(
        track.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent && player.isPlaying)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.graphic_eq, color: SwaraTheme.accent),
            ),
          IconButton(
            tooltip: player.isFavourite(track)
                ? 'Remove from favourites'
                : 'Add to favourites',
            icon: Icon(
              player.isFavourite(track)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: player.isFavourite(track)
                  ? SwaraTheme.accent
                  : scheme.onSurfaceVariant,
            ),
            onPressed: () => player.toggleFavourite(track),
          ),
        ],
      ),
      onTap: () => player.playTrack(track, queue: queue),
    );
  }
}

/// Compact player docked above the navigation bar once something is playing.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final track = player.current;
    if (track == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final progress = player.duration.inMilliseconds == 0
        ? 0.0
        : player.position.inMilliseconds / player.duration.inMilliseconds;

    return Material(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => NowPlayingScreen.open(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              color: SwaraTheme.accent,
              backgroundColor: Colors.transparent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Hero(
                    tag: 'cover',
                    child: CoverArt(track: track, size: 44, radius: 6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          track.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: player.isPlaying ? 'Pause' : 'Play',
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    iconSize: 32,
                    onPressed: player.togglePlay,
                  ),
                  IconButton(
                    tooltip: 'Next',
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: player.next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
