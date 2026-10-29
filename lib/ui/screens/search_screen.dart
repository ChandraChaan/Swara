import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/languages.dart';
import '../../data/catalog_repository.dart';
import '../../data/library_store.dart';
import '../../models/collection.dart';
import '../../models/song.dart';
import '../../services/app_state.dart';
import '../../services/player_controller.dart';
import '../widgets/artwork.dart';
import '../widgets/song_tile.dart';
import 'song_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  Future<SearchResults>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
    setState(() {});
  }

  void _search(String value, {bool save = false}) {
    final q = value.trim();
    if (save) context.read<LibraryStore>().addRecentSearch(q);
    setState(() {
      _query = q;
      _results = q.isEmpty || !context.read<AppState>().online
          ? null
          : context.read<CatalogRepository>().search(q);
    });
  }

  void _searchFor(String q) {
    _controller.text = q;
    _focus.unfocus();
    _search(q, save: true);
  }

  /// Matches across everything stored on the device, so search works
  /// offline too.
  List<Song> _librarySongs(LibraryStore store) {
    final q = _query.toLowerCase();
    final seen = <String>{};
    final all = [
      ...store.downloads.map((d) => d.offlineSong),
      ...store.deviceSongs,
      ...store.likedSongs,
      ...store.history,
      ...CatalogRepository.bundled,
    ];
    return all
        .where(
          (s) =>
              (s.title.toLowerCase().contains(q) ||
                  s.artist.toLowerCase().contains(q) ||
                  s.album.toLowerCase().contains(q)) &&
              seen.add(s.key),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppState>().online;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) => _search(v, save: true),
          decoration: InputDecoration(
            hintText: online
                ? 'Songs, artists, albums… (పాటలు)'
                : 'Search your offline library',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
          ),
        ),
      ),
      body: _query.isEmpty ? _Browse(onSearch: _searchFor) : _buildResults(),
    );
  }

  Widget _buildResults() {
    final store = context.watch<LibraryStore>();
    final library = _librarySongs(store);
    if (_results == null) {
      return _ResultList(
        library: library,
        results: const SearchResults(),
        loading: false,
      );
    }
    return FutureBuilder<SearchResults>(
      future: _results,
      builder: (context, snap) => _ResultList(
        library: library,
        results: snap.data ?? const SearchResults(),
        loading: snap.connectionState != ConnectionState.done,
      ),
    );
  }
}

class _Browse extends StatelessWidget {
  const _Browse({required this.onSearch});

  final void Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<LibraryStore>();
    final recent = store.recentSearches;
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        if (recent.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent searches',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: store.clearRecentSearches,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final q in recent)
                    ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: Text(q),
                      onPressed: () => onSearch(q),
                    ),
                ],
              ),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text('Browse all', style: theme.textTheme.titleLarge),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid.builder(
            itemCount: browseTiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 96,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, i) {
              final tile = browseTiles[i];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSearch(tile.query),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: tile.colors.map(Color.new).toList(),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -12,
                        bottom: -12,
                        child: Transform.rotate(
                          angle: 0.4,
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 72,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          tile.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({
    required this.library,
    required this.results,
    required this.loading,
  });

  final List<Song> library;
  final SearchResults results;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    final online = context.watch<AppState>().online;
    final theme = Theme.of(context);
    final libraryKeys = library.map((s) => s.key).toSet();
    final remoteSongs = results.songs
        .where((s) => !libraryKeys.contains(s.key))
        .toList();
    final collections = [...results.albums, ...results.playlists];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleMedium),
    );

    final noResults = !loading && library.isEmpty && results.isEmpty;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (!online)
          const ListTile(
            leading: Icon(Icons.cloud_off_rounded),
            title: Text('Offline – showing songs saved on this device'),
          ),
        if (library.isNotEmpty) ...[
          header('In your library'),
          for (var i = 0; i < library.length; i++)
            SongTile(
              song: library[i],
              onTap: () => player.playSongs(library, startIndex: i),
            ),
        ],
        if (remoteSongs.isNotEmpty) ...[
          header('Songs'),
          for (var i = 0; i < remoteSongs.length; i++)
            SongTile(
              song: remoteSongs[i],
              onTap: () => player.playSongs(remoteSongs, startIndex: i),
            ),
        ],
        if (collections.isNotEmpty) ...[
          header('Albums & playlists'),
          for (final c in collections) _CollectionTile(collection: c),
        ],
        if (results.errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Some sources did not respond: ${results.errors.join(', ')}',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (noResults)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 56),
                SizedBox(height: 12),
                Text(
                  'No results. Try another spelling, or search in '
                  'English and Telugu (e.g. "prema" / "ప్రేమ").',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.collection});

  final SongCollection collection;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Artwork(
        url: collection.artworkUrl,
        size: 50,
        seed: collection.key,
        icon: Icons.album_rounded,
      ),
      title: Text(
        collection.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${collection.source.label} • ${collection.subtitle}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CollectionScreen(collection: collection),
        ),
      ),
    );
  }
}
