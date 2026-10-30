import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/library_store.dart';
import '../../models/collection.dart';
import '../../services/download_manager.dart';
import '../../services/local_import_service.dart';
import '../widgets/artwork.dart';
import '../widgets/song_actions.dart';
import 'song_list_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final downloads = context.watch<DownloadManager>();
    final active = downloads.tasks;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Library',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Create playlist',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final name = await askPlaylistName(context);
              if (name != null && name.trim().isNotEmpty) {
                await store.createPlaylist(name);
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _Entry(
            icon: Icons.favorite_rounded,
            colors: const [Color(0xFF7C4DFF), Color(0xFFE91E63)],
            title: 'Liked Songs',
            subtitle: '${store.likedSongs.length} songs',
            onTap: () => _push(context, (_) => const _LikedScreen()),
          ),
          _Entry(
            icon: Icons.download_for_offline_rounded,
            colors: const [Color(0xFF1DB954), Color(0xFF0B6E4F)],
            title: 'Downloads',
            subtitle: active.isEmpty
                ? '${store.downloads.length} songs • '
                      '${formatBytes(store.downloadedBytes)}'
                : 'Downloading ${active.length}…',
            onTap: () => _push(context, (_) => const DownloadsScreen()),
          ),
          _Entry(
            icon: Icons.phone_android_rounded,
            colors: const [Color(0xFFFF6B35), Color(0xFFFFC107)],
            title: 'On this device',
            subtitle: '${store.deviceSongs.length} imported songs',
            onTap: () => _push(context, (_) => const _DeviceScreen()),
          ),
          _Entry(
            icon: Icons.history_rounded,
            colors: const [Color(0xFF3949AB), Color(0xFF00B8D4)],
            title: 'Recently played',
            subtitle: '${store.history.length} songs',
            onTap: () => _push(context, (_) => const _HistoryScreen()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Playlists', style: theme.textTheme.titleLarge),
          ),
          if (store.playlists.isEmpty)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.add_rounded)),
              title: const Text('Create your first playlist'),
              subtitle: const Text('Mix Telugu hits, devotional and more'),
              onTap: () async {
                final name = await askPlaylistName(context);
                if (name != null && name.trim().isNotEmpty) {
                  await store.createPlaylist(name);
                }
              },
            ),
          for (final p in store.playlists)
            ListTile(
              leading: Artwork(
                url: p.songs.firstOrNull?.artworkUrl,
                size: 56,
                seed: p.name,
                icon: Icons.queue_music_rounded,
              ),
              title: Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Playlist • ${p.songs.length} songs'),
              onTap: () =>
                  _push(context, (_) => PlaylistScreen(playlistId: p.id)),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> colors;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(colors: colors),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}

class _LikedScreen extends StatelessWidget {
  const _LikedScreen();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    return SongListScreen(
      title: 'Liked Songs',
      icon: Icons.favorite_rounded,
      artworkUrl: null,
      songs: store.likedSongs,
      onRemove: store.toggleLike,
      removeLabel: 'Remove from Liked Songs',
      emptyText: 'Songs you like will appear here.\nTap ♡ on any song.',
    );
  }
}

class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    return SongListScreen(
      title: 'Recently played',
      icon: Icons.history_rounded,
      songs: store.history,
      actions: [
        IconButton(
          tooltip: 'Clear history',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: store.clearHistory,
        ),
      ],
      emptyText: 'Songs you play will show up here.',
    );
  }
}

class _DeviceScreen extends StatelessWidget {
  const _DeviceScreen();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    Future<void> import() async {
      final n = await context.read<LocalImportService>().pickAndImport();
      if (context.mounted && n > 0) showMessage(context, 'Added $n songs');
    }

    return SongListScreen(
      title: 'On this device',
      icon: Icons.phone_android_rounded,
      songs: store.deviceSongs,
      onRemove: store.removeDeviceSong,
      removeLabel: 'Remove from library',
      actions: [
        IconButton(
          tooltip: 'Add songs from phone',
          icon: const Icon(Icons.library_add_rounded),
          onPressed: import,
        ),
      ],
      headerExtra: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: OutlinedButton.icon(
          onPressed: import,
          icon: const Icon(Icons.library_add_rounded),
          label: const Text('Add songs from your phone'),
        ),
      ),
      emptyText:
          'Already have Telugu MP3s on your phone?\n'
          'Add them here to play offline with lyrics, queue and more.',
    );
  }
}

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final manager = context.watch<DownloadManager>();
    final records = store.downloads;
    final active = manager.tasks;

    return SongListScreen(
      title: 'Downloads',
      subtitle: formatBytes(store.downloadedBytes),
      icon: Icons.download_for_offline_rounded,
      songs: records.map((r) => r.offlineSong).toList(),
      onRemove: manager.delete,
      removeLabel: 'Remove download',
      actions: [
        if (records.isNotEmpty)
          IconButton(
            tooltip: 'Remove all downloads',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Remove all downloads?'),
                  content: Text(
                    'This frees '
                    '${formatBytes(store.downloadedBytes)}. You can '
                    'download the songs again later.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              );
              if (ok == true) await manager.deleteAll();
            },
          ),
      ],
      headerExtra: active.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'In progress',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final t in active)
                  ListTile(
                    leading: Artwork(
                      url: t.song.artworkUrl,
                      size: 44,
                      seed: t.song.key,
                    ),
                    title: Text(
                      t.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: t.status == DownloadStatus.failed
                        ? Text(
                            'Failed – ${t.error ?? 'try again'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : LinearProgressIndicator(value: t.progress),
                    trailing: t.status == DownloadStatus.failed
                        ? IconButton(
                            tooltip: 'Retry',
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () => manager.retry(t.song),
                          )
                        : IconButton(
                            tooltip: 'Cancel',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => manager.cancel(t.song),
                          ),
                  ),
                const Divider(),
              ],
            ),
      emptyText:
          'Download songs to listen without internet.\n'
          'Tap ⬇ on any song or album.',
    );
  }
}

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final UserPlaylist? playlist = store.playlist(playlistId);
    if (playlist == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    return SongListScreen(
      title: playlist.name,
      subtitle: 'Your playlist',
      icon: Icons.queue_music_rounded,
      songs: playlist.songs,
      onRemove: (song) {
        playlist.songs.remove(song);
        store.savePlaylist(playlist);
      },
      removeLabel: 'Remove from this playlist',
      onReorder: (from, to) {
        playlist.songs.insert(to, playlist.songs.removeAt(from));
        store.savePlaylist(playlist);
      },
      actions: [
        PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'rename') {
              final name = await askPlaylistName(
                context,
                initial: playlist.name,
                title: 'Rename playlist',
              );
              if (name != null && name.trim().isNotEmpty) {
                playlist.name = name.trim();
                await store.savePlaylist(playlist);
              }
            } else if (action == 'delete') {
              await store.deletePlaylist(playlist.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
          ],
        ),
      ],
      emptyText:
          'Add songs from search or any album using\n'
          '⋮ › Add to playlist.',
    );
  }
}
