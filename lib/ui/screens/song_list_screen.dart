import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/catalog_repository.dart';
import '../../models/collection.dart';
import '../../models/song.dart';
import '../../services/download_manager.dart';
import '../../services/player_controller.dart';
import '../widgets/artwork.dart';
import '../widgets/artwork_color.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

/// A full-page list of songs with a big header: used for albums, playlists,
/// liked songs, downloads, device songs and history.
class SongListScreen extends StatelessWidget {
  const SongListScreen({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.artworkUrl,
    this.icon = Icons.album_rounded,
    this.numbered = false,
    this.onRemove,
    this.removeLabel = 'Remove',
    this.onReorder,
    this.actions = const [],
    this.emptyText = 'Nothing here yet',
    this.headerExtra,
  });

  final String title;
  final String? subtitle;
  final String? artworkUrl;
  final IconData icon;
  final List<Song> songs;
  final bool numbered;
  final void Function(Song song)? onRemove;
  final String removeLabel;
  final void Function(int from, int to)? onReorder;
  final List<Widget> actions;
  final String emptyText;
  final Widget? headerExtra;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final total = songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + (s.duration ?? Duration.zero),
    );
    final art = artworkUrl ?? songs.firstOrNull?.artworkUrl;

    Widget tile(int i) => SongTile(
      key: ValueKey(songs[i].key),
      song: songs[i],
      index: numbered ? i : null,
      onTap: () => player.playSongs(songs, startIndex: i),
      onRemove: onRemove == null ? null : () => onRemove!(songs[i]),
      removeLabel: removeLabel,
      trailing: onReorder == null
          ? null
          : ReorderableDragStartListener(
              index: i,
              child: const Icon(Icons.drag_handle_rounded),
            ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 330,
            actions: actions,
            flexibleSpace: FlexibleSpaceBar(
              background: ArtworkColorBuilder(
                artworkUrl: art,
                fallback: Theme.of(context).colorScheme.primary,
                builder: (context, color) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0.75),
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Material(
                              elevation: 12,
                              borderRadius: BorderRadius.circular(8),
                              child: Artwork(
                                url: art,
                                size: 170,
                                seed: title,
                                icon: icon,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            [
                              if (subtitle != null && subtitle!.isNotEmpty)
                                subtitle!,
                              '${songs.length} songs',
                              if (total > Duration.zero) formatDuration(total),
                            ].join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _ActionRow(songs: songs)),
          if (headerExtra != null) SliverToBoxAdapter(child: headerExtra),
          if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(emptyText, textAlign: TextAlign.center),
                ),
              ),
            )
          else if (onReorder != null)
            SliverReorderableList(
              itemCount: songs.length,
              onReorderItem: (from, to) => onReorder!(from, to),
              itemBuilder: (_, i) => tile(i),
            )
          else
            SliverList.builder(
              itemCount: songs.length,
              itemBuilder: (_, i) => tile(i),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox(height: 8);
    final player = context.read<PlayerController>();
    final downloads = context.read<DownloadManager>();
    final downloadable = songs.where(DownloadManager.canDownload).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
      child: Row(
        children: [
          if (downloadable.isNotEmpty)
            IconButton(
              tooltip: 'Download all',
              icon: const Icon(Icons.download_for_offline_outlined),
              onPressed: () {
                final n = downloads.enqueue(downloadable);
                showMessage(
                  context,
                  n == 0
                      ? 'All songs are already downloaded'
                      : 'Downloading $n songs for offline listening',
                );
              },
            ),
          IconButton(
            tooltip: 'Add to playlist',
            icon: const Icon(Icons.playlist_add_rounded),
            onPressed: () => showAddToPlaylist(context, songs),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Shuffle play',
            iconSize: 28,
            icon: const Icon(Icons.shuffle_rounded),
            onPressed: () => player.playSongs(songs, shuffle: true),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: null,
            tooltip: 'Play',
            onPressed: () => player.playSongs(songs),
            shape: const CircleBorder(),
            child: const Icon(Icons.play_arrow_rounded, size: 34),
          ),
        ],
      ),
    );
  }
}

/// Loads an online album or playlist, then shows it as a [SongListScreen].
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.collection});

  final SongCollection collection;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<List<Song>> _tracks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _tracks = context.read<CatalogRepository>().tracks(widget.collection);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    return FutureBuilder<List<Song>>(
      future: _tracks,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: Text(c.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(c.title)),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48),
                  const SizedBox(height: 12),
                  const Text("Couldn't load this album"),
                  TextButton(
                    onPressed: () => setState(_load),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        return SongListScreen(
          title: c.title,
          subtitle: c.subtitle,
          artworkUrl: c.artworkUrl,
          songs: snap.data!,
          numbered: true,
          emptyText: 'No playable tracks in this album',
        );
      },
    );
  }
}
