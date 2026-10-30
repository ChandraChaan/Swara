import 'dart:io';

import 'package:swara/data/catalog_repository.dart';
import 'package:swara/data/library_store.dart';
import 'package:swara/services/download_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

void main() {
  late LibraryStore store;

  setUp(() async => store = await openTempStore());
  tearDown(closeTempStore);

  group('LibraryStore', () {
    test('likes toggle and list newest first', () async {
      final a = onlineSong('a');
      final b = onlineSong('b');
      await store.toggleLike(a);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await store.toggleLike(b);
      expect(store.isLiked(a), isTrue);
      expect(store.likedSongs, [b, a]);
      await store.toggleLike(a);
      expect(store.isLiked(a), isFalse);
      expect(store.likedSongs, [b]);
    });

    test('playlists: create, add without duplicates, delete', () async {
      final p = await store.createPlaylist('  Telugu melodies ');
      expect(p.name, 'Telugu melodies');
      expect(await store.addToPlaylist(p.id, onlineSong('a')), isTrue);
      expect(await store.addToPlaylist(p.id, onlineSong('a')), isFalse);
      expect(await store.addToPlaylist(p.id, deviceSong('b')), isTrue);
      expect(store.playlist(p.id)!.songs.map((s) => s.id), ['a', 'b']);
      await store.deletePlaylist(p.id);
      expect(store.playlists, isEmpty);
    });

    test('history is most-recent-first, deduplicated and capped', () async {
      for (var i = 0; i < LibraryStore.historyLimit + 5; i++) {
        await store.addToHistory(onlineSong('$i'));
      }
      await store.addToHistory(onlineSong('3'));
      final history = store.history;
      expect(history.length, LibraryStore.historyLimit);
      expect(history.first.id, '3');
      expect(history.where((s) => s.id == '3'), hasLength(1));
    });

    test('top artists come from history', () async {
      await store.addToHistory(onlineSong('1'));
      await store.addToHistory(deviceSong('x')); // Unknown artist is ignored.
      // Built-in tracks are ignored too.
      await store.addToHistory(CatalogRepository.bundled.first);
      expect(store.topArtists(), ['Artist 1']);
    });

    test('recent searches are unique, case-insensitive and capped', () async {
      await store.addRecentSearch('Telugu');
      await store.addRecentSearch('  ');
      await store.addRecentSearch('ghantasala');
      await store.addRecentSearch('telugu');
      expect(store.recentSearches, ['telugu', 'ghantasala']);
      for (var i = 0; i < 20; i++) {
        await store.addRecentSearch('q$i');
      }
      expect(store.recentSearches.length, LibraryStore.recentSearchLimit);
    });

    test('session and preferences persist', () async {
      await store.saveSession(
        [onlineSong('a'), onlineSong('b')],
        1,
        const Duration(seconds: 30),
      );
      expect(store.lastSession!['index'], 1);
      expect(store.pref('offlineMode', false), isFalse);
      await store.setPref('offlineMode', true);
      expect(store.pref('offlineMode', false), isTrue);
    });
  });

  group('DownloadManager', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('dl'));

    test('downloads audio and artwork, then records it', () async {
      final client = MockClient.streaming((req, _) async {
        final body = req.url.path.endsWith('.jpg') ? [1, 2, 3] : [7, 7, 7, 7];
        return http.StreamedResponse(
          Stream.value(body),
          200,
          contentLength: body.length,
        );
      });
      final manager = DownloadManager(
        store: store,
        directory: () async => dir,
        client: client,
      );
      final song = onlineSong('a');
      expect(manager.enqueue([song, deviceSong('local')]), 1);
      expect(manager.isBusy(song), isTrue);
      while (manager.isBusy(song)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final record = store.download(song)!;
      expect(record.bytes, 4);
      expect(File(record.path).readAsBytesSync(), [7, 7, 7, 7]);
      expect(record.path, endsWith('.mp3'));
      expect(File(record.artworkPath!).readAsBytesSync(), [1, 2, 3]);
      expect(record.offlineSong.artworkUrl, record.artworkPath);

      // Already downloaded songs are not queued again.
      expect(manager.enqueue([song]), 0);

      await manager.delete(song);
      expect(store.isDownloaded(song), isFalse);
      expect(File(record.path).existsSync(), isFalse);
    });

    test('marks failures and can retry', () async {
      var fail = true;
      final client = MockClient.streaming(
        (req, _) async => fail
            ? http.StreamedResponse(const Stream.empty(), 404)
            : http.StreamedResponse(Stream.value([1]), 200),
      );
      final manager = DownloadManager(
        store: store,
        directory: () async => dir,
        client: client,
      );
      final song = onlineSong('b');
      manager.enqueue([song]);
      while (manager.task(song)?.status != DownloadStatus.failed) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(store.isDownloaded(song), isFalse);
      expect(dir.listSync(recursive: true).whereType<File>(), isEmpty);

      fail = false;
      manager.retry(song);
      while (manager.isBusy(song)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(store.isDownloaded(song), isTrue);
    });
  });
}
