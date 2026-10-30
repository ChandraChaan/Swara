import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/library_store.dart';
import '../../models/song.dart';
import '../../services/download_manager.dart';
import '../../services/player_controller.dart';
import 'artwork.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> shareSong(Song song) {
  final link = song.source.isOnline ? '\n${song.uri}' : '';
  return SharePlus.instance.share(
    ShareParams(
      text: '🎵 ${song.title} — ${song.artist}$link\n\nListening on Swara',
    ),
  );
}

/// Asks for a playlist name. Returns null if cancelled.
Future<String?> askPlaylistName(
  BuildContext context, {
  String initial = '',
  String title = 'New playlist',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Telugu road trip'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> showAddToPlaylist(BuildContext context, List<Song> songs) async {
  final store = context.read<LibraryStore>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final playlists = store.playlists;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.add)),
                title: const Text('New playlist'),
                onTap: () async {
                  final name = await askPlaylistName(sheetContext);
                  if (name == null || name.trim().isEmpty) return;
                  await store.createPlaylist(name, songs);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) showMessage(context, 'Created "$name"');
                },
              ),
              for (final p in playlists)
                ListTile(
                  leading: Artwork(
                    url: p.songs.firstOrNull?.artworkUrl,
                    size: 44,
                    seed: p.name,
                    icon: Icons.queue_music_rounded,
                  ),
                  title: Text(p.name),
                  subtitle: Text('${p.songs.length} songs'),
                  onTap: () async {
                    var added = 0;
                    for (final s in songs) {
                      if (await store.addToPlaylist(p.id, s)) added++;
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    if (context.mounted) {
                      showMessage(
                        context,
                        added == 0
                            ? 'Already in "${p.name}"'
                            : 'Added to "${p.name}"',
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// The long-press / overflow menu for a song.
Future<void> showSongActions(
  BuildContext context,
  Song song, {
  VoidCallback? onRemove,
  String removeLabel = 'Remove',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final player = context.read<PlayerController>();
      final downloads = context.read<DownloadManager>();
      return Consumer<LibraryStore>(
        builder: (_, store, _) {
          final liked = store.isLiked(song);
          final downloaded = store.isDownloaded(song);
          void close() => Navigator.pop(sheetContext);
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Artwork(
                      url: song.artworkUrl,
                      size: 52,
                      seed: song.key,
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.playlist_play_rounded),
                    title: const Text('Play next'),
                    onTap: () {
                      close();
                      player.playNext(song);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: const Text('Add to queue'),
                    onTap: () {
                      close();
                      player.addToQueue(song);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    title: Text(liked ? 'Remove from Liked Songs' : 'Like'),
                    onTap: () => store.toggleLike(song),
                  ),
                  ListTile(
                    leading: const Icon(Icons.playlist_add_rounded),
                    title: const Text('Add to playlist'),
                    onTap: () {
                      close();
                      showAddToPlaylist(context, [song]);
                    },
                  ),
                  if (DownloadManager.canDownload(song))
                    ListTile(
                      leading: Icon(
                        downloaded
                            ? Icons.download_done_rounded
                            : Icons.download_rounded,
                      ),
                      title: Text(downloaded ? 'Remove download' : 'Download'),
                      onTap: () {
                        close();
                        if (downloaded) {
                          downloads.delete(song);
                          showMessage(context, 'Download removed');
                        } else {
                          downloads.enqueue([song]);
                          showMessage(context, 'Downloading "${song.title}"');
                        }
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.share_rounded),
                    title: const Text('Share'),
                    onTap: () {
                      close();
                      shareSong(song);
                    },
                  ),
                  if (onRemove != null)
                    ListTile(
                      leading: const Icon(Icons.remove_circle_outline_rounded),
                      title: Text(removeLabel),
                      onTap: () {
                        close();
                        onRemove();
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
