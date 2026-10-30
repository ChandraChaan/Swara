import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import 'audio_engine.dart' as engine;
import 'audio_engine.dart' show AudioEngine, EngineState, PlayableSong;

/// Bridges just_audio to the operating system: background playback, the
/// media notification, lock screen, headphone buttons, Bluetooth, Android
/// Auto and CarPlay style controls all go through this handler.
class AppAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements AudioEngine {
  AppAudioHandler() {
    _player = AudioPlayer(
      maxSkipsOnError: 3,
      audioPipeline: Platform.isAndroid
          ? AudioPipeline(androidAudioEffects: [_equalizer, _loudness])
          : null,
    );
    _init();
  }

  static Future<AppAudioHandler> create() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    return AudioService.init(
      builder: AppAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.chandrachaan.swara.playback',
        androidNotificationChannelName: 'Music playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        preloadArtwork: true,
      ),
    );
  }

  late final AudioPlayer _player;
  final _equalizer = AndroidEqualizer();
  final _loudness = AndroidLoudnessEnhancer();
  final _errors = StreamController<String>.broadcast();

  void _init() {
    _player.playbackEventStream.map(_transform).pipe(playbackState);

    _player.currentIndexStream.listen((index) {
      final items = queue.value;
      if (index != null && index < items.length) mediaItem.add(items[index]);
    });

    // Fill in durations that the catalog did not know so the notification
    // shows a proper seek bar.
    _player.durationStream.listen((duration) {
      final index = _player.currentIndex;
      final items = [...queue.value];
      if (duration == null || index == null || index >= items.length) return;
      if (items[index].duration == duration) return;
      items[index] = items[index].copyWith(duration: duration);
      queue.add(items);
      mediaItem.add(items[index]);
    });

    _player.errorStream.listen(
      (e) => _errors.add(e.message ?? 'Playback error'),
    );
  }

  PlaybackState _transform(PlaybackEvent event) {
    final playing = _player.playing;
    return playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  static MediaItem _mediaItem(Song song) {
    final art = song.artworkUrl;
    Uri? artUri;
    if (art != null) {
      if (art.startsWith('http')) {
        artUri = Uri.parse(art);
      } else if (!art.startsWith('asset:')) {
        artUri = Uri.file(art);
      }
    }
    return MediaItem(
      id: song.key,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.duration,
      artUri: artUri,
      genre: song.genre,
    );
  }

  static AudioSource _source(PlayableSong item) {
    final tag = _mediaItem(item.song);
    final location = item.location;
    if (location.startsWith('asset:///')) {
      return AudioSource.asset(
        location.substring('asset:///'.length),
        tag: tag,
      );
    }
    if (location.startsWith('http')) {
      return AudioSource.uri(Uri.parse(location), tag: tag);
    }
    return AudioSource.file(location, tag: tag);
  }

  // ---------------------------------------------------------------------
  // AudioEngine
  // ---------------------------------------------------------------------

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Stream<EngineState> get stateStream =>
      _player.processingStateStream.map((s) => EngineState.values[s.index]);

  @override
  Stream<String> get errorStream => _errors.stream;

  @override
  Duration get position => _player.position;

  @override
  List<int> get effectiveIndices => _player.effectiveIndices;

  @override
  Future<void> setQueue(
    List<PlayableSong> items, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  }) async {
    queue.add(items.map((i) => _mediaItem(i.song)).toList());
    try {
      await _player.setAudioSources(
        items.map(_source).toList(),
        initialIndex: initialIndex,
        initialPosition: initialPosition,
      );
    } on PlayerInterruptedException {
      // A newer queue replaced this one.
    } on PlayerException catch (e) {
      _errors.add(e.message ?? 'Could not load this song');
    }
  }

  @override
  Future<void> insert(int index, PlayableSong item) async {
    queue.add([...queue.value]..insert(index, _mediaItem(item.song)));
    await _player.insertAudioSource(index, _source(item));
  }

  @override
  Future<void> removeAt(int index) async {
    queue.add([...queue.value]..removeAt(index));
    await _player.removeAudioSourceAt(index);
  }

  @override
  Future<void> move(int from, int to) async {
    final items = [...queue.value];
    items.insert(to, items.removeAt(from));
    queue.add(items);
    await _player.moveAudioSource(from, to);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);

  @override
  Future<void> next() => _player.seekToNext();

  /// Like every major player: restart the song if it has been playing for a
  /// few seconds, otherwise go to the previous one.
  @override
  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    if (enabled) await _player.shuffle();
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setRepeat(engine.RepeatSetting mode) => _player.setLoopMode(
    const [LoopMode.off, LoopMode.all, LoopMode.one][mode.index],
  );

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<engine.EqualizerInfo?> equalizer() async {
    if (!Platform.isAndroid) return null;
    try {
      final params = await _equalizer.parameters.timeout(
        const Duration(seconds: 3),
      );
      return engine.EqualizerInfo(
        params.minDecibels,
        params.maxDecibels,
        params.bands
            .map(
              (b) => engine.EqualizerBand(b.index, b.centerFrequency, b.gain),
            )
            .toList(),
      );
    } catch (_) {
      // The equalizer only becomes available once something has loaded.
      return null;
    }
  }

  @override
  Future<void> setEqualizerEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    await _equalizer.setEnabled(enabled);
  }

  @override
  Future<void> setBandGain(int band, double gain) async {
    if (!Platform.isAndroid) return;
    final params = await _equalizer.parameters;
    await params.bands[band].setGain(gain);
  }

  @override
  Future<void> setLoudnessBoost(double db) async {
    if (!Platform.isAndroid) return;
    await _loudness.setEnabled(db > 0);
    await _loudness.setTargetGain(db);
  }

  // ---------------------------------------------------------------------
  // System media controls
  // ---------------------------------------------------------------------

  @override
  Future<void> skipToNext() => next();

  @override
  Future<void> skipToPrevious() => previous();

  @override
  Future<void> skipToQueueItem(int index) =>
      _player.seek(Duration.zero, index: index);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      setShuffle(shuffleMode != AudioServiceShuffleMode.none);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        return setRepeat(engine.RepeatSetting.off);
      case AudioServiceRepeatMode.one:
        return setRepeat(engine.RepeatSetting.one);
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        return setRepeat(engine.RepeatSetting.all);
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    if (!_player.playing) await stop();
  }
}
