import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lyrics.dart';
import '../models/song.dart';

/// Fetches time-synced lyrics from LRCLIB, a free and open lyrics database.
class LyricsService {
  LyricsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final _cache = <String, Lyrics>{};

  static String _clean(String s) => s
      .replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<Lyrics> fetch(Song song) async {
    final cached = _cache[song.key];
    if (cached != null) return cached;
    final uri = Uri.https('lrclib.net', '/api/search', {
      'track_name': _clean(song.title),
      if (!song.artist.startsWith('Unknown')) 'artist_name': song.artist,
    });
    final res = await _client
        .get(
          uri,
          headers: {
            'User-Agent':
                'SwaraMusic/2.0 (https://github.com/ChandraChaan/Swara)',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return const Lyrics();
    final lyrics = pickBest(jsonDecode(res.body) as List, song.duration);
    _cache[song.key] = lyrics;
    return lyrics;
  }

  /// Prefers synced lyrics whose duration is within a few seconds of the
  /// song, then any synced lyrics, then plain text.
  static Lyrics pickBest(List<dynamic> results, Duration? duration) {
    final items = results.cast<Map<String, dynamic>>();
    bool closeEnough(Map<String, dynamic> r) {
      final d = r['duration'];
      if (duration == null || d is! num) return true;
      return (d - duration.inSeconds).abs() <= 4;
    }

    Map<String, dynamic>? best;
    for (final r in items) {
      if (r['syncedLyrics'] is String && closeEnough(r)) {
        best = r;
        break;
      }
    }
    best ??= items.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r!['syncedLyrics'] is String,
      orElse: () => null,
    );
    best ??= items.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r!['plainLyrics'] is String,
      orElse: () => null,
    );
    if (best == null) return const Lyrics();
    final synced = best['syncedLyrics'] as String?;
    return Lyrics(
      synced: synced == null ? const [] : Lyrics.parseLrc(synced),
      plain: best['plainLyrics'] as String?,
    );
  }
}
