import 'dart:convert';

import 'package:swara/data/catalog_repository.dart';
import 'package:swara/data/lyrics_service.dart';
import 'package:swara/data/sources/archive_source.dart';
import 'package:swara/data/sources/audius_source.dart';
import 'package:swara/data/sources/music_source.dart';
import 'package:swara/models/collection.dart';
import 'package:swara/models/song.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ArchiveSource', () {
    test('parses search results', () {
      final albums = ArchiveSource.parseSearch({
        'response': {
          'docs': [
            {
              'identifier': 'annamacharya-keerthanalu',
              'title': 'Annamacharya Keerthanalu',
              'creator': ['M. S. Subbulakshmi', 'Other'],
            },
            {'identifier': 'no-title'},
          ],
        },
      });
      expect(albums, hasLength(2));
      expect(albums[0].title, 'Annamacharya Keerthanalu');
      expect(albums[0].subtitle, 'M. S. Subbulakshmi');
      expect(
        albums[0].artworkUrl,
        'https://archive.org/services/img/annamacharya-keerthanalu',
      );
      expect(albums[1].title, 'no-title');
      expect(albums[1].subtitle, 'Internet Archive');
    });

    test('picks one MP3 per track, ordered by track number', () {
      final songs = ArchiveSource.parseItem('telugu-hits', {
        'metadata': {
          'title': 'Telugu Hits',
          'creator': 'Various',
          'language': 'tel',
        },
        'files': [
          {'name': '02 Second.flac', 'source': 'original', 'format': 'Flac'},
          {
            'name': '02 Second.mp3',
            'source': 'derivative',
            'format': 'VBR MP3',
            'track': '2',
            'length': '200.5',
          },
          {
            'name': 'disc 1/01 First Song.mp3',
            'source': 'original',
            'format': 'VBR MP3',
            'title': 'First Song',
            'creator': 'Ghantasala',
            'track': '1/10',
            'length': '3:05',
          },
          {'name': 'cover.jpg', 'source': 'original', 'format': 'JPEG'},
          {'name': 'telugu-hits_meta.xml', 'format': 'Metadata'},
        ],
      });
      expect(songs.map((s) => s.title), ['First Song', '02 Second']);
      expect(songs[0].artist, 'Ghantasala');
      expect(songs[1].artist, 'Various');
      expect(songs[0].album, 'Telugu Hits');
      expect(songs[0].duration, const Duration(minutes: 3, seconds: 5));
      expect(
        songs[0].uri,
        'https://archive.org/download/telugu-hits/disc%201/01%20First%20Song.mp3',
      );
      expect(songs[0].language, 'tel');
      expect(songs.every((s) => s.source == SongSource.archive), isTrue);
    });

    test('fetches an item through the metadata API', () async {
      final client = MockClient((req) async {
        expect(req.url.toString(), 'https://archive.org/metadata/item1');
        return http.Response(
          jsonEncode({
            'metadata': {'title': 'Album'},
            'files': [
              {'name': 'a.mp3', 'format': 'VBR MP3', 'source': 'original'},
            ],
          }),
          200,
        );
      });
      final source = ArchiveSource(client: client);
      final songs = await source.collectionTracks(
        const SongCollection(
          id: 'item1',
          source: SongSource.archive,
          title: 'Album',
        ),
      );
      expect(songs.single.title, 'a');
    });
  });

  group('AudiusSource', () {
    Map<String, dynamic> track(String id, {bool streamable = true}) => {
      'id': id,
      'title': ' Track $id ',
      'user': {'name': 'Artist $id'},
      'artwork': {'480x480': 'https://img/$id.jpg'},
      'duration': 181.6,
      'genre': 'World',
      'is_streamable': streamable,
    };

    test('discovers a host and searches tracks', () async {
      final client = MockClient((req) async {
        if (req.url.host == 'api.audius.co') {
          return http.Response(
            jsonEncode({
              'data': ['https://node.audius.test'],
            }),
            200,
          );
        }
        expect(req.url.host, 'node.audius.test');
        expect(req.url.path, '/v1/tracks/search');
        expect(req.url.queryParameters['query'], 'telugu');
        expect(req.url.queryParameters['app_name'], AudiusSource.appName);
        return http.Response(
          jsonEncode({
            'data': [track('a'), track('b', streamable: false), track('c')],
          }),
          200,
        );
      });
      final songs = await AudiusSource(client: client).searchSongs('telugu');
      expect(songs.map((s) => s.id), ['a', 'c']);
      expect(songs[0].title, 'Track a');
      expect(songs[0].artist, 'Artist a');
      expect(songs[0].duration, const Duration(seconds: 182));
      expect(songs[0].artworkUrl, 'https://img/a.jpg');
      expect(
        songs[0].uri,
        'https://node.audius.test/v1/tracks/a/stream?app_name=${AudiusSource.appName}',
      );
    });

    test('falls back to a known host when discovery fails', () async {
      final client = MockClient((req) async {
        if (req.url.host == 'api.audius.co') return http.Response('', 500);
        return http.Response(jsonEncode({'data': []}), 200);
      });
      final songs = await AudiusSource(client: client).searchSongs('x');
      expect(songs, isEmpty);
    });

    test('throws on server errors', () async {
      final client = MockClient(
        (req) async => req.url.host == 'api.audius.co'
            ? http.Response(
                jsonEncode({
                  'data': ['https://n'],
                }),
                200,
              )
            : http.Response('oops', 503),
      );
      expect(
        AudiusSource(client: client).searchSongs('x'),
        throwsA(isA<SourceException>()),
      );
    });
  });

  group('CatalogRepository', () {
    test(
      'search survives a failing source and includes bundled songs',
      () async {
        final repo = CatalogRepository(
          sources: [
            _FakeSource(SongSource.audius, fail: true),
            _FakeSource(SongSource.archive),
          ],
        );
        final results = await repo.search('mohanam');
        expect(results.songs.single.title, 'Mohanam Dawn');
        expect(results.albums.single.title, 'Album for mohanam');
        expect(results.errors, containsAll(['Audius', 'Audius playlists']));
      },
    );

    test('caches results', () async {
      final source = _FakeSource(SongSource.audius);
      final repo = CatalogRepository(sources: [source]);
      await repo.songs('telugu');
      await repo.songs('telugu');
      expect(source.calls, 1);
      repo.clearCache();
      await repo.songs('telugu');
      expect(source.calls, 2);
    });
  });

  group('LyricsService.pickBest', () {
    test('prefers synced lyrics with matching duration', () {
      final lyrics = LyricsService.pickBest([
        {'duration': 100, 'syncedLyrics': '[00:01.00]wrong'},
        {'duration': 181, 'syncedLyrics': '[00:01.00]right'},
      ], const Duration(seconds: 182));
      expect(lyrics.synced.single.text, 'right');
    });

    test('falls back to plain lyrics', () {
      final lyrics = LyricsService.pickBest([
        {'duration': 181, 'plainLyrics': 'just text'},
      ], null);
      expect(lyrics.isSynced, isFalse);
      expect(lyrics.plain, 'just text');
    });

    test('empty when nothing found', () {
      expect(LyricsService.pickBest([], null).isEmpty, isTrue);
    });
  });
}

class _FakeSource implements MusicSource {
  _FakeSource(this.source, {this.fail = false});

  @override
  final SongSource source;
  final bool fail;
  int calls = 0;

  @override
  Future<List<Song>> searchSongs(String query, {int limit = 20}) async {
    calls++;
    if (fail) throw SourceException('down');
    return [
      Song(id: query, source: source, title: 'Song for $query', uri: 'x'),
    ];
  }

  @override
  Future<List<SongCollection>> searchCollections(
    String query, {
    int limit = 20,
  }) async {
    if (fail) throw SourceException('down');
    return [
      SongCollection(id: query, source: source, title: 'Album for $query'),
    ];
  }

  @override
  Future<List<Song>> collectionTracks(SongCollection collection) async =>
      const [];
}
