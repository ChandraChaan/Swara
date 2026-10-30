import '../models/collection.dart';
import '../models/song.dart';
import 'sources/archive_source.dart';
import 'sources/audius_source.dart';
import 'sources/music_source.dart';

class SearchResults {
  const SearchResults({
    this.songs = const [],
    this.albums = const [],
    this.playlists = const [],
    this.errors = const [],
  });

  final List<Song> songs;
  final List<SongCollection> albums;
  final List<SongCollection> playlists;

  /// Sources that failed; results from the others are still shown.
  final List<String> errors;

  bool get isEmpty => songs.isEmpty && albums.isEmpty && playlists.isEmpty;
}

/// Single entry point for online catalog data, with a short-lived in-memory
/// cache so moving between screens does not refetch everything.
class CatalogRepository {
  CatalogRepository({List<MusicSource>? sources})
    : _sources = {
        for (final s in sources ?? [AudiusSource(), ArchiveSource()])
          s.source: s,
      };

  static const cacheTtl = Duration(minutes: 20);

  final Map<SongSource, MusicSource> _sources;
  final _cache = <String, (DateTime, Object)>{};

  /// Telugu songs bundled with the app so there is always something to play,
  /// even on first launch without internet.
  static const bundled = <Song>[
    Song(
      id: 'mastaaru_mastaaru',
      source: SongSource.asset,
      title: 'Mastaaru Mastaaru',
      artist: 'Shweta Mohan',
      album: 'Sir (2023)',
      uri: 'asset:///assets/audio/mastaaru_mastaaru.mp3',
      artworkUrl: 'asset:///assets/artwork/mastaaru_mastaaru.jpg',
      language: 'te',
    ),
    Song(
      id: 'ediparavasamo',
      source: SongSource.asset,
      title: 'Edi Paravasamo',
      artist: 'Haripriya',
      album: 'Kurup (2021)',
      uri: 'asset:///assets/audio/ediparavasamo.mp3',
      artworkUrl: 'asset:///assets/artwork/ediparavasamo.jpg',
      language: 'te',
    ),
    Song(
      id: 'dingiridingale',
      source: SongSource.asset,
      title: 'Dingiri Dingale',
      artist: 'Deepak Blue',
      album: 'Kurup (2021)',
      uri: 'asset:///assets/audio/dingiridingale.mp3',
      artworkUrl: 'asset:///assets/artwork/dingiridingale.jpg',
      language: 'te',
    ),
    Song(
      id: 'anuvynakaalam',
      source: SongSource.asset,
      title: 'Anuvynakaalam',
      artist: 'Surmukhi Raman',
      album: 'Kurup (2021)',
      uri: 'asset:///assets/audio/anuvynakaalam.mp3',
      artworkUrl: 'asset:///assets/artwork/anuvynakaalam.jpg',
      language: 'te',
    ),
  ];

  Future<T> _cached<T extends Object>(
    String key,
    Future<T> Function() load,
  ) async {
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.$1) < cacheTtl) {
      return hit.$2 as T;
    }
    final value = await load();
    _cache[key] = (DateTime.now(), value);
    return value;
  }

  void clearCache() => _cache.clear();

  Future<List<Song>> songs(String query, {int limit = 20}) {
    final source = _sources[SongSource.audius];
    if (source == null) return Future.value(const []);
    return _cached(
      'songs:$query:$limit',
      () => source.searchSongs(query, limit: limit),
    );
  }

  Future<List<SongCollection>> albums(String query, {int limit = 20}) {
    final source = _sources[SongSource.archive];
    if (source == null) return Future.value(const []);
    return _cached(
      'albums:$query:$limit',
      () => source.searchCollections(query, limit: limit),
    );
  }

  Future<List<SongCollection>> playlists(String query, {int limit = 20}) {
    final source = _sources[SongSource.audius];
    if (source == null) return Future.value(const []);
    return _cached(
      'playlists:$query:$limit',
      () => source.searchCollections(query, limit: limit),
    );
  }

  Future<List<Song>> tracks(SongCollection collection) {
    final source = _sources[collection.source];
    if (source == null) {
      throw SourceException('No source for ${collection.source.label}');
    }
    return _cached(
      'tracks:${collection.key}',
      () => source.collectionTracks(collection),
    );
  }

  /// Searches every source in parallel; a failing source never hides the
  /// results of the others.
  Future<SearchResults> search(String query) async {
    final errors = <String>[];
    Future<List<T>> guard<T>(String name, Future<List<T>> f) async {
      try {
        return await f;
      } catch (_) {
        errors.add(name);
        return <T>[];
      }
    }

    final results = await Future.wait([
      guard('Audius', songs(query, limit: 30)),
      guard('Internet Archive', albums(query, limit: 24)),
      guard('Audius playlists', playlists(query, limit: 12)),
    ]);
    final q = query.toLowerCase();
    final local = bundled
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q),
        )
        .toList();
    return SearchResults(
      songs: [...local, ...results[0].cast<Song>()],
      albums: results[1].cast<SongCollection>(),
      playlists: results[2].cast<SongCollection>(),
      errors: errors,
    );
  }
}
