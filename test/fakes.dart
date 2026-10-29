import 'dart:async';
import 'dart:io';

import 'package:audioplayer/data/library_store.dart';
import 'package:audioplayer/models/song.dart';
import 'package:audioplayer/services/audio_engine.dart';
import 'package:hive_ce/hive.dart';

Song onlineSong(String id, {String? title}) => Song(
  id: id,
  source: SongSource.audius,
  title: title ?? 'Song $id',
  artist: 'Artist $id',
  uri: 'https://example.com/$id.mp3',
  artworkUrl: 'https://example.com/$id.jpg',
  duration: const Duration(minutes: 3),
);

Song deviceSong(String id) => Song(
  id: id,
  source: SongSource.device,
  title: 'Local $id',
  uri: '/music/$id.mp3',
);

Future<LibraryStore> openTempStore() async {
  final dir = await Directory.systemTemp.createTemp('swara_test');
  Hive.init(dir.path);
  return LibraryStore.open();
}

Future<void> closeTempStore() => Hive.deleteFromDisk();

/// In-memory [AudioEngine] that records calls and lets tests emit events.
class FakeEngine implements AudioEngine {
  final playing = StreamController<bool>.broadcast();
  final positions = StreamController<Duration>.broadcast();
  final indexes = StreamController<int?>.broadcast();
  final states = StreamController<EngineState>.broadcast();
  final errors = StreamController<String>.broadcast();

  List<PlayableSong> items = [];
  int? initialIndex;
  bool isPlaying = false;
  bool shuffle = false;
  RepeatSetting repeat = RepeatSetting.off;
  double speed = 1;
  double volume = 1;
  final calls = <String>[];

  @override
  Stream<bool> get playingStream => playing.stream;
  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration> get bufferedPositionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<int?> get currentIndexStream => indexes.stream;
  @override
  Stream<EngineState> get stateStream => states.stream;
  @override
  Stream<String> get errorStream => errors.stream;
  @override
  Duration get position => Duration.zero;
  @override
  List<int> get effectiveIndices => List.generate(items.length, (i) => i);

  @override
  Future<void> setQueue(
    List<PlayableSong> items, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  }) async {
    this.items = [...items];
    this.initialIndex = initialIndex;
    calls.add('setQueue');
  }

  @override
  Future<void> insert(int index, PlayableSong item) async =>
      items.insert(index, item);
  @override
  Future<void> removeAt(int index) async => items.removeAt(index);
  @override
  Future<void> move(int from, int to) async =>
      items.insert(to, items.removeAt(from));
  @override
  Future<void> play() async {
    isPlaying = true;
    calls.add('play');
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    calls.add('pause');
  }

  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> seek(Duration position, {int? index}) async =>
      calls.add('seek:${position.inSeconds}:$index');
  @override
  Future<void> next() async => calls.add('next');
  @override
  Future<void> previous() async => calls.add('previous');
  @override
  Future<void> setShuffle(bool enabled) async => shuffle = enabled;
  @override
  Future<void> setRepeat(RepeatSetting mode) async => repeat = mode;
  @override
  Future<void> setSpeed(double speed) async => this.speed = speed;
  @override
  Future<void> setVolume(double volume) async => this.volume = volume;
  @override
  Future<EqualizerInfo?> equalizer() async => null;
  @override
  Future<void> setEqualizerEnabled(bool enabled) async {}
  @override
  Future<void> setBandGain(int band, double gain) async {}
  @override
  Future<void> setLoudnessBoost(double db) async {}
}
