import 'package:audioplayer/core/format.dart';
import 'package:audioplayer/models/collection.dart';
import 'package:audioplayer/models/lyrics.dart';
import 'package:audioplayer/models/song.dart';
import 'package:audioplayer/services/local_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Song', () {
    test('round-trips through JSON', () {
      const song = Song(
        id: '42',
        source: SongSource.archive,
        title: 'Vinaro Bhagyamu',
        artist: 'M. S. Subbulakshmi',
        album: 'Annamacharya Keerthanalu',
        uri: 'https://archive.org/download/x/1.mp3',
        artworkUrl: 'https://archive.org/services/img/x',
        duration: Duration(seconds: 245),
        language: 'te',
      );
      final copy = Song.fromJson(song.toJson());
      expect(copy.key, 'archive:42');
      expect(copy.title, song.title);
      expect(copy.album, song.album);
      expect(copy.duration, song.duration);
      expect(copy.language, 'te');
      expect(copy, song);
    });

    test('equality is by source and id', () {
      const a = Song(id: '1', source: SongSource.audius, title: 'A', uri: 'x');
      const b = Song(id: '1', source: SongSource.audius, title: 'B', uri: 'y');
      const c = Song(id: '1', source: SongSource.device, title: 'A', uri: 'x');
      expect(a, b);
      expect(a == c, isFalse);
    });

    test('only streaming sources are online', () {
      expect(SongSource.audius.isOnline, isTrue);
      expect(SongSource.archive.isOnline, isTrue);
      expect(SongSource.asset.isOnline, isFalse);
      expect(SongSource.device.isOnline, isFalse);
    });
  });

  test('UserPlaylist round-trips through JSON', () {
    final p = UserPlaylist(
      id: 'p1',
      name: 'Road trip',
      songs: [
        const Song(id: '1', source: SongSource.asset, title: 'A', uri: 'x'),
      ],
    );
    final copy = UserPlaylist.fromJson(p.toJson());
    expect(copy.name, 'Road trip');
    expect(copy.songs.single.title, 'A');
    expect(
      copy.createdAt.millisecondsSinceEpoch,
      p.createdAt.millisecondsSinceEpoch,
    );
  });

  group('Lyrics', () {
    const lrc = '''
[ar:Someone]
[00:12.50]First line
[00:05.00]Intro
[00:20.1][00:40.123]Chorus
not a lyric line
''';

    test('parses and sorts LRC including repeated tags', () {
      final lines = Lyrics.parseLrc(lrc);
      expect(lines.map((l) => l.text), [
        'Intro',
        'First line',
        'Chorus',
        'Chorus',
      ]);
      expect(lines[1].time, const Duration(seconds: 12, milliseconds: 500));
      expect(lines[2].time, const Duration(seconds: 20, milliseconds: 100));
      expect(lines[3].time, const Duration(seconds: 40, milliseconds: 123));
    });

    test('finds the active line', () {
      final lyrics = Lyrics(synced: Lyrics.parseLrc(lrc));
      expect(lyrics.indexAt(Duration.zero), -1);
      expect(lyrics.indexAt(const Duration(seconds: 5)), 0);
      expect(lyrics.indexAt(const Duration(seconds: 15)), 1);
      expect(lyrics.indexAt(const Duration(minutes: 5)), 3);
    });

    test('empty when nothing usable', () {
      expect(const Lyrics().isEmpty, isTrue);
      expect(const Lyrics(plain: '  ').isEmpty, isTrue);
      expect(const Lyrics(plain: 'la la').isEmpty, isFalse);
    });
  });

  group('format', () {
    test('formatDuration', () {
      expect(formatDuration(null), '--:--');
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
      expect(formatDuration(const Duration(minutes: 4, seconds: 7)), '4:07');
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('formatBytes', () {
      expect(formatBytes(500), '500 B');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    });

    test('parseLooseDuration accepts archive formats', () {
      expect(
        parseLooseDuration('245.5'),
        const Duration(seconds: 245, milliseconds: 500),
      );
      expect(
        parseLooseDuration('4:05'),
        const Duration(minutes: 4, seconds: 5),
      );
      expect(
        parseLooseDuration('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(parseLooseDuration(90), const Duration(seconds: 90));
      expect(parseLooseDuration(''), isNull);
      expect(parseLooseDuration('abc'), isNull);
      expect(parseLooseDuration(null), isNull);
    });

    test('greeting includes Telugu', () {
      expect(greeting(DateTime(2026, 1, 1, 8)), contains('శుభోదయం'));
      expect(greeting(DateTime(2026, 1, 1, 20)), contains('సాయంత్రం'));
    });
  });

  test('cleanTitle strips download-site prefixes', () {
    expect(
      LocalImportService.cleanTitle('[iSongs.info] 01 - Edi Paravasamo'),
      'Edi Paravasamo',
    );
    expect(
      LocalImportService.cleanTitle('03. Samajavaragamana'),
      'Samajavaragamana',
    );
    expect(LocalImportService.cleanTitle('Butta Bomma'), 'Butta Bomma');
  });
}
