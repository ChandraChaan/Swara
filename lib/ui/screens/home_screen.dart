import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/languages.dart';
import '../../data/catalog_repository.dart';
import '../../data/library_store.dart';
import '../../models/collection.dart';
import '../../models/song.dart';
import '../../services/player_controller.dart';
import '../../services/settings_controller.dart';
import '../../services/app_state.dart';
import '../widgets/artwork.dart';
import '../widgets/cards.dart';
import '../widgets/song_actions.dart';
import 'settings_screen.dart';
import 'song_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _refreshToken = 0;

  Future<void> _refresh() async {
    context.read<CatalogRepository>().clearCache();
    setState(() => _refreshToken++);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final online = context.watch<AppState>().online;
    final store = context.watch<LibraryStore>();
    final lang = settings.primaryLanguage;
    final history = store.history;
    final offlineSongs = [
      ...store.downloads.map((d) => d.offlineSong),
      ...store.deviceSongs,
      ...CatalogRepository.bundled,
    ];
    final topArtists = store.topArtists(limit: 2);
    final extraLanguages = settings.languageCodes
        .skip(1)
        .map(languageByCode)
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          key: ValueKey('home-$_refreshToken-${lang.code}'),
          slivers: [
            SliverAppBar(
              floating: true,
              titleSpacing: 16,
              toolbarHeight: 64,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting(DateTime.now()),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Swara • ${lang.nativeName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _LanguageChips(selected: lang.code)),
            if (!online) const SliverToBoxAdapter(child: _OfflineBanner()),
            if (history.isNotEmpty)
              SliverToBoxAdapter(
                child: _QuickPicks(songs: history.take(6).toList()),
              ),
            SliverToBoxAdapter(
              child: _SongRow(
                title: online ? 'Play offline anytime' : 'Your offline music',
                songs: offlineSongs,
              ),
            ),
            if (online) ...[
              for (final artist in topArtists)
                SliverToBoxAdapter(
                  child: _RemoteSongRow(
                    title: 'More like $artist',
                    query: artist,
                  ),
                ),
              for (final spec in sectionsFor(lang))
                SliverToBoxAdapter(
                  child: spec.albums
                      ? _RemoteAlbumRow(title: spec.title, query: spec.query)
                      : _RemoteSongRow(title: spec.title, query: spec.query),
                ),
              for (final extra in extraLanguages)
                SliverToBoxAdapter(
                  child: _RemoteSongRow(
                    title: 'Trending in ${extra.name}',
                    query: extra.keywords.first,
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _LanguageChips extends StatelessWidget {
  const _LanguageChips({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsController>();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: languages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final l = languages[i];
          return ChoiceChip(
            label: Text(
              l.code == 'en' ? l.name : '${l.name} • ${l.nativeName}',
            ),
            selected: l.code == selected,
            onSelected: (_) => settings.setPrimaryLanguage(l.code),
          );
        },
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final forced = context.watch<SettingsController>().offlineMode;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              forced
                  ? 'Offline mode is on. Only downloaded and device songs '
                        'play. Turn it off in Settings.'
                  : "You're offline. Your downloads, device songs and "
                        'built-in songs still play.',
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 2-column grid of recently played songs, like Spotify's home shortcuts.
class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Jump back in', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: songs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 56,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, i) {
              final song = songs[i];
              final playable = player.canPlay(song);
              return Opacity(
                opacity: playable ? 1 : 0.45,
                child: Material(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => player.playSongs(songs, startIndex: i),
                    onLongPress: () => showSongActions(context, song),
                    child: Row(
                      children: [
                        Artwork(
                          url: song.artworkUrl,
                          size: 56,
                          radius: 0,
                          seed: song.key,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({required this.title, required this.songs});

  final String title;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final player = context.read<PlayerController>();
    return Carousel(
      title: title,
      itemCount: songs.length,
      onSeeAll: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SongListScreen(title: title, songs: songs),
        ),
      ),
      itemBuilder: (context, i) => SongCard(
        song: songs[i],
        onTap: () => player.playSongs(songs, startIndex: i),
        onLongPress: () => showSongActions(context, songs[i]),
      ),
    );
  }
}

class _RemoteSongRow extends StatefulWidget {
  const _RemoteSongRow({required this.title, required this.query});

  final String title;
  final String query;

  @override
  State<_RemoteSongRow> createState() => _RemoteSongRowState();
}

class _RemoteSongRowState extends State<_RemoteSongRow> {
  late final Future<List<Song>> _songs = context
      .read<CatalogRepository>()
      .songs(widget.query);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Song>>(
      future: _songs,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return CarouselSkeleton(title: widget.title);
        }
        // A section that fails or is empty simply disappears.
        return _SongRow(title: widget.title, songs: snap.data ?? const []);
      },
    );
  }
}

class _RemoteAlbumRow extends StatefulWidget {
  const _RemoteAlbumRow({required this.title, required this.query});

  final String title;
  final String query;

  @override
  State<_RemoteAlbumRow> createState() => _RemoteAlbumRowState();
}

class _RemoteAlbumRowState extends State<_RemoteAlbumRow> {
  late final Future<List<SongCollection>> _albums = context
      .read<CatalogRepository>()
      .albums(widget.query);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SongCollection>>(
      future: _albums,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return CarouselSkeleton(title: widget.title);
        }
        final albums = snap.data ?? const [];
        if (albums.isEmpty) return const SizedBox.shrink();
        return Carousel(
          title: widget.title,
          itemCount: albums.length,
          itemBuilder: (context, i) => CollectionCard(
            collection: albums[i],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CollectionScreen(collection: albums[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}
