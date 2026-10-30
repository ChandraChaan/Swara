import 'package:swara/data/library_store.dart';
import 'package:swara/services/audio_engine.dart';
import 'package:swara/services/player_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late LibraryStore store;
  late FakeEngine engine;
  late PlayerController player;
  var online = true;

  setUp(() async {
    store = await openTempStore();
    engine = FakeEngine();
    online = true;
    player = PlayerController(
      engine: engine,
      store: store,
      isOnline: () => online,
    );
  });

  tearDown(() async {
    player.dispose();
    await closeTempStore();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('plays a list from the chosen index', () async {
    final songs = [onlineSong('a'), onlineSong('b'), onlineSong('c')];
    final skipped = await player.playSongs(songs, startIndex: 1);
    expect(skipped, 0);
    expect(engine.items.map((i) => i.song.id), ['a', 'b', 'c']);
    expect(engine.initialIndex, 1);
    expect(engine.calls, contains('play'));
    expect(player.current!.id, 'b');
  });

  test('offline: skips songs that are not downloaded', () async {
    online = false;
    final messages = <String>[];
    player.messages.listen(messages.add);
    final songs = [onlineSong('a'), deviceSong('local'), onlineSong('c')];
    final skipped = await player.playSongs(songs, startIndex: 1);
    await pump();
    expect(skipped, 2);
    expect(engine.items.single.song.id, 'local');
    expect(messages.single, contains('2 songs skipped'));
  });

  test('offline with nothing playable leaves the queue alone', () async {
    online = false;
    final messages = <String>[];
    player.messages.listen(messages.add);
    await player.playSongs([onlineSong('a')]);
    await pump();
    expect(engine.calls, isEmpty);
    expect(messages.single, contains('offline'));
  });

  test('downloaded songs play from the local file', () async {
    final song = onlineSong('a');
    await store.saveDownload(
      DownloadRecord(
        song: song,
        path: '/data/a.mp3',
        artworkPath: '/data/a.art',
        bytes: 10,
        downloadedAt: DateTime(2026),
      ),
    );
    online = false;
    await player.playSongs([song]);
    expect(engine.items.single.location, '/data/a.mp3');
    expect(engine.items.single.song.artworkUrl, '/data/a.art');
  });

  test('play next and add to queue', () async {
    await player.playSongs([onlineSong('a'), onlineSong('b')]);
    engine.indexes.add(0);
    await pump();
    await player.playNext(onlineSong('x'));
    await player.addToQueue(onlineSong('y'));
    expect(player.queue.map((s) => s.id), ['a', 'x', 'b', 'y']);
    expect(engine.items.map((i) => i.song.id), ['a', 'x', 'b', 'y']);

    // Moving an existing song to "next" does not duplicate it.
    await player.playNext(onlineSong('y'));
    expect(player.queue.map((s) => s.id), ['a', 'y', 'x', 'b']);
    expect(engine.items.map((i) => i.song.id), ['a', 'y', 'x', 'b']);
  });

  test('reorder and remove keep the current song tracked', () async {
    await player.playSongs([
      onlineSong('a'),
      onlineSong('b'),
      onlineSong('c'),
    ], startIndex: 1);
    engine.indexes.add(1);
    await pump();
    await player.move(2, 0);
    expect(player.queue.map((s) => s.id), ['c', 'a', 'b']);
    expect(player.current!.id, 'b');
    await player.removeAt(0);
    expect(player.queue.map((s) => s.id), ['a', 'b']);
    expect(player.current!.id, 'b');
    // The current song cannot be removed.
    await player.removeAt(1);
    expect(player.queue, hasLength(2));
  });

  test('records history when the song changes', () async {
    await player.playSongs([onlineSong('a'), onlineSong('b')]);
    engine.indexes.add(0);
    await pump();
    engine.indexes.add(1);
    await pump();
    expect(store.history.map((s) => s.id), ['b', 'a']);
  });

  test('repeat cycles off → all → one → off', () async {
    await player.cycleRepeat();
    expect(engine.repeat, RepeatSetting.all);
    await player.cycleRepeat();
    expect(engine.repeat, RepeatSetting.one);
    await player.cycleRepeat();
    expect(engine.repeat, RepeatSetting.off);
  });

  test('shuffle play turns shuffle on', () async {
    await player.playSongs([onlineSong('a'), onlineSong('b')], shuffle: true);
    expect(player.shuffle, isTrue);
    expect(engine.shuffle, isTrue);
  });

  test('sleep timer at end of song pauses on the next song', () async {
    await player.playSongs([onlineSong('a'), onlineSong('b')]);
    engine.indexes.add(0);
    await pump();
    player.setSleepTimer(null, endOfSong: true);
    expect(player.sleepTimerActive, isTrue);
    engine.indexes.add(1);
    await pump();
    expect(engine.calls, contains('pause'));
    expect(player.sleepTimerActive, isFalse);
  });

  test('sleep timer can be set and cancelled', () {
    player.setSleepTimer(const Duration(minutes: 15));
    expect(player.sleepRemaining!.inMinutes, inInclusiveRange(14, 15));
    player.setSleepTimer(null);
    expect(player.sleepTimerActive, isFalse);
  });

  test('restores the last session without autoplay', () async {
    await store.saveSession(
      [onlineSong('a'), onlineSong('b')],
      1,
      const Duration(seconds: 42),
    );
    await player.restoreSession();
    expect(player.current!.id, 'b');
    expect(engine.initialIndex, 1);
    expect(engine.calls, isNot(contains('play')));
  });
}
