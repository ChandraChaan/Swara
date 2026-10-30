import '../../models/collection.dart';
import '../../models/song.dart';

/// A catalog the app can search and stream from.
///
/// To plug in a licensed catalog (for example a label or aggregator API),
/// implement this interface and register it in `CatalogRepository`.
abstract class MusicSource {
  SongSource get source;

  Future<List<Song>> searchSongs(String query, {int limit = 20});

  Future<List<SongCollection>> searchCollections(
    String query, {
    int limit = 20,
  });

  Future<List<Song>> collectionTracks(SongCollection collection);
}

class SourceException implements Exception {
  SourceException(this.message);

  final String message;

  @override
  String toString() => message;
}
