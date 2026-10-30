import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/format.dart';
import '../../models/collection.dart';
import '../../models/song.dart';
import 'music_source.dart';

/// The Internet Archive hosts a very large library of Indian audio:
/// devotional albums, Carnatic concerts, folk recordings and old film songs.
/// Each archive item is treated as an album.
class ArchiveSource implements MusicSource {
  ArchiveSource({http.Client? client}) : _client = client ?? http.Client();

  static const _base = 'https://archive.org';
  final http.Client _client;

  @override
  SongSource get source => SongSource.archive;

  static String artworkFor(String identifier) =>
      '$_base/services/img/$identifier';

  @override
  Future<List<Song>> searchSongs(String query, {int limit = 20}) async =>
      const [];

  @override
  Future<List<SongCollection>> searchCollections(
    String query, {
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_base/advancedsearch.php').replace(
      queryParameters: {
        'q': '($query) AND mediatype:(audio)',
        'fl[]': ['identifier', 'title', 'creator'],
        'sort[]': 'downloads desc',
        'rows': '$limit',
        'page': '1',
        'output': 'json',
      },
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw SourceException('Internet Archive returned ${res.statusCode}');
    }
    return parseSearch(jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  Future<List<Song>> collectionTracks(SongCollection collection) async {
    final res = await _client
        .get(Uri.parse('$_base/metadata/${collection.id}'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw SourceException('Internet Archive returned ${res.statusCode}');
    }
    return parseItem(
      collection.id,
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  static String _text(Object? value, String fallback) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  static List<SongCollection> parseSearch(Map<String, dynamic> json) {
    final docs = (json['response']?['docs'] as List?) ?? const [];
    return docs.cast<Map<String, dynamic>>().map((d) {
      final id = d['identifier'] as String;
      return SongCollection(
        id: id,
        source: SongSource.archive,
        title: _text(d['title'], id),
        subtitle: _text(d['creator'], 'Internet Archive'),
        artworkUrl: artworkFor(id),
      );
    }).toList();
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static bool _isMp3(Map f) =>
      (f['format'] as String? ?? '').contains('MP3') ||
      (f['name'] as String).toLowerCase().endsWith('.mp3');

  /// Picks one playable MP3 per track out of an item's file list, preferring
  /// originals over derivatives and ordering by track number.
  static List<Song> parseItem(String identifier, Map<String, dynamic> json) {
    final meta = (json['metadata'] as Map?) ?? const {};
    final album = _text(meta['title'], identifier);
    final albumArtist = _text(meta['creator'], 'Various artists');
    final language = _text(meta['language'], '');
    final files = ((json['files'] as List?) ?? const [])
        .cast<Map>()
        .where((f) => f['name'] is String && _isMp3(f))
        .toList();

    final byStem = <String, Map>{};
    for (final f in files) {
      final stem = _stem(f['name'] as String);
      final existing = byStem[stem];
      if (existing == null ||
          (existing['source'] != 'original' && f['source'] == 'original')) {
        byStem[stem] = f;
      }
    }

    int trackNo(Map f) =>
        int.tryParse((f['track'] as String? ?? '').split('/').first) ?? 9999;

    final picked = byStem.values.toList()
      ..sort((a, b) {
        final t = trackNo(a).compareTo(trackNo(b));
        return t != 0
            ? t
            : (a['name'] as String).compareTo(b['name'] as String);
      });

    return picked.map((f) {
      final name = f['name'] as String;
      final fileName = name.split('/').last;
      return Song(
        id: '$identifier/$name',
        source: SongSource.archive,
        title: _text(f['title'], _stem(fileName).replaceAll('_', ' ')),
        artist: _text(f['creator'] ?? f['artist'], albumArtist),
        album: album,
        uri:
            '$_base/download/$identifier/'
            '${name.split('/').map(Uri.encodeComponent).join('/')}',
        artworkUrl: artworkFor(identifier),
        duration: parseLooseDuration(f['length']),
        language: language.isEmpty ? null : language,
      );
    }).toList();
  }
}
