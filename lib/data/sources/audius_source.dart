import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../models/collection.dart';
import '../../models/song.dart';
import 'music_source.dart';

/// Audius is an open, artist-owned streaming network with a free public API
/// that allows streaming in third-party apps.
class AudiusSource implements MusicSource {
  AudiusSource({http.Client? client}) : _client = client ?? http.Client();

  static const appName = 'SwaraMusic';
  static const _fallbackHosts = [
    'https://discoveryprovider.audius.co',
    'https://discoveryprovider2.audius.co',
    'https://discoveryprovider3.audius.co',
  ];

  final http.Client _client;
  String? _host;

  @override
  SongSource get source => SongSource.audius;

  Future<String> _resolveHost() async {
    if (_host != null) return _host!;
    try {
      final res = await _client
          .get(Uri.parse('https://api.audius.co'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final hosts = (jsonDecode(res.body)['data'] as List).cast<String>();
        if (hosts.isNotEmpty) {
          return _host = hosts[Random().nextInt(hosts.length)];
        }
      }
    } catch (_) {
      // Fall through to the well-known hosts.
    }
    return _host = _fallbackHosts.first;
  }

  Future<List<dynamic>> _get(String path, Map<String, String> params) async {
    final host = await _resolveHost();
    final uri = Uri.parse(
      '$host/v1$path',
    ).replace(queryParameters: {...params, 'app_name': appName});
    final res = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      _host = null; // Pick another host next time.
      throw SourceException('Audius returned ${res.statusCode}');
    }
    return (jsonDecode(res.body)['data'] as List?) ?? const [];
  }

  @override
  Future<List<Song>> searchSongs(String query, {int limit = 20}) async {
    final data = await _get('/tracks/search', {'query': query});
    final host = await _resolveHost();
    return data
        .cast<Map<String, dynamic>>()
        .where((t) => t['is_streamable'] != false)
        .take(limit)
        .map((t) => parseTrack(t, host))
        .toList();
  }

  @override
  Future<List<SongCollection>> searchCollections(
    String query, {
    int limit = 20,
  }) async {
    final data = await _get('/playlists/search', {'query': query});
    return data.cast<Map<String, dynamic>>().take(limit).map((p) {
      return SongCollection(
        id: p['id'] as String,
        source: source,
        title: p['playlist_name'] as String? ?? 'Playlist',
        subtitle: (p['user'] as Map?)?['name'] as String? ?? 'Audius',
        artworkUrl: _artwork(p['artwork']),
      );
    }).toList();
  }

  @override
  Future<List<Song>> collectionTracks(SongCollection collection) async {
    final data = await _get('/playlists/${collection.id}/tracks', {});
    final host = await _resolveHost();
    return data
        .cast<Map<String, dynamic>>()
        .where((t) => t['is_streamable'] != false)
        .map((t) => parseTrack(t, host, album: collection.title))
        .toList();
  }

  static String? _artwork(Object? artwork) {
    if (artwork is! Map) return null;
    return (artwork['480x480'] ?? artwork['1000x1000'] ?? artwork['150x150'])
        as String?;
  }

  static Song parseTrack(Map<String, dynamic> t, String host, {String? album}) {
    final id = t['id'] as String;
    final duration = t['duration'];
    return Song(
      id: id,
      source: SongSource.audius,
      title: (t['title'] as String? ?? 'Untitled').trim(),
      artist: (t['user'] as Map?)?['name'] as String? ?? 'Unknown artist',
      album: album ?? t['genre'] as String? ?? '',
      uri: '$host/v1/tracks/$id/stream?app_name=$appName',
      artworkUrl: _artwork(t['artwork']),
      duration: duration is num ? Duration(seconds: duration.round()) : null,
      genre: t['genre'] as String?,
    );
  }
}
