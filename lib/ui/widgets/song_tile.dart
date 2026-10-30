import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/library_store.dart';
import '../../models/song.dart';
import '../../services/download_manager.dart';
import '../../services/player_controller.dart';
import 'artwork.dart';
import 'song_actions.dart';

/// Shows whether a song is downloaded or downloading.
class DownloadIndicator extends StatelessWidget {
  const DownloadIndicator({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final downloaded = context.select<LibraryStore, bool>(
      (s) => s.isDownloaded(song),
    );
    final task = context.watch<DownloadManager>().task(song);
    final color = Theme.of(context).colorScheme.primary;
    if (downloaded) {
      return Icon(Icons.download_done_rounded, size: 16, color: color);
    }
    if (task == null) return const SizedBox.shrink();
    if (task.status == DownloadStatus.failed) {
      return const Icon(
        Icons.error_outline_rounded,
        size: 16,
        color: Colors.redAccent,
      );
    }
    return SizedBox(
      width: 14,
      height: 14,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        value: task.progress,
        color: color,
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.index,
    this.onRemove,
    this.removeLabel = 'Remove',
    this.trailing,
  });

  final Song song;
  final VoidCallback onTap;

  /// Shows a track number instead of artwork when set.
  final int? index;
  final VoidCallback? onRemove;
  final String removeLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = context.select<PlayerController, bool>(
      (p) => p.current == song,
    );
    final playable = context.select<PlayerController, bool>(
      (p) => p.canPlay(song),
    );
    final titleColor = isCurrent ? theme.colorScheme.primary : null;

    return Opacity(
      opacity: playable ? 1 : 0.45,
      child: ListTile(
        onTap: onTap,
        onLongPress: () => showSongActions(
          context,
          song,
          onRemove: onRemove,
          removeLabel: removeLabel,
        ),
        leading: index != null
            ? SizedBox(
                width: 32,
                child: Center(
                  child: isCurrent
                      ? Icon(Icons.graphic_eq_rounded, color: titleColor)
                      : Text(
                          '${index! + 1}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              )
            : Artwork(
                url: song.artworkUrl,
                size: 50,
                radius: 6,
                seed: song.key,
              ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            DownloadIndicator(song: song),
            if (context.select<LibraryStore, bool>((s) => s.isDownloaded(song)))
              const SizedBox(width: 4),
            Expanded(
              child: Text(
                song.duration == null
                    ? song.subtitle
                    : '${song.subtitle} • ${formatDuration(song.duration)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing:
            trailing ??
            IconButton(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => showSongActions(
                context,
                song,
                onRemove: onRemove,
                removeLabel: removeLabel,
              ),
            ),
      ),
    );
  }
}
