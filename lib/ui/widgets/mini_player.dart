import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/library_store.dart';
import '../../services/player_controller.dart';
import '../screens/player_screen.dart';
import 'artwork.dart';
import 'artwork_color.dart';

/// The compact player docked above the navigation bar. Tap to expand, swipe
/// sideways to change songs.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();
    final liked = context.select<LibraryStore, bool>((s) => s.isLiked(song));

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: ArtworkColorBuilder(
        artworkUrl: song.artworkUrl,
        fallback: const Color(0xFF2A2A33),
        builder: (context, color) => Material(
          color: Color.lerp(color, Colors.black, 0.55),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openPlayer(context),
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -300) player.next();
                if (v > 300) player.previous();
              },
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -300) openPlayer(context);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'artwork',
                          child: Artwork(
                            url: song.artworkUrl,
                            size: 42,
                            radius: 6,
                            seed: song.key,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [...previous, ?current],
                            ),
                            child: Column(
                              key: ValueKey(song.key),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: liked ? 'Unlike' : 'Like',
                          color: Colors.white,
                          icon: Icon(
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                          onPressed: () =>
                              context.read<LibraryStore>().toggleLike(song),
                        ),
                        SizedBox(
                          width: 44,
                          child: player.buffering && player.playing
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : IconButton(
                                  tooltip: player.playing ? 'Pause' : 'Play',
                                  color: Colors.white,
                                  icon: Icon(
                                    player.playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                  iconSize: 30,
                                  onPressed: player.togglePlay,
                                ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snap) {
                      final total = player.duration?.inMilliseconds ?? 0;
                      final pos = snap.data?.inMilliseconds ?? 0;
                      return LinearProgressIndicator(
                        minHeight: 2,
                        value: total == 0 ? 0 : (pos / total).clamp(0.0, 1.0),
                        color: Colors.white,
                        backgroundColor: Colors.white24,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
