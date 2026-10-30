import '../models/song.dart';

enum RepeatSetting { off, all, one }

enum EngineState { idle, loading, buffering, ready, completed }

/// A song paired with the location it should actually be played from (a
/// downloaded file, a bundled asset or a network stream).
class PlayableSong {
  const PlayableSong(this.song, this.location);

  final Song song;
  final String location;
}

class EqualizerBand {
  const EqualizerBand(this.index, this.centerHz, this.gain);

  final int index;
  final double centerHz;
  final double gain;
}

class EqualizerInfo {
  const EqualizerInfo(this.minDb, this.maxDb, this.bands);

  final double minDb;
  final double maxDb;
  final List<EqualizerBand> bands;
}

/// The playback backend used by `PlayerController`. The production
/// implementation is `AppAudioHandler`; tests use a fake.
abstract class AudioEngine {
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<Duration?> get durationStream;
  Stream<int?> get currentIndexStream;
  Stream<EngineState> get stateStream;
  Stream<String> get errorStream;

  Duration get position;

  /// Playback order: indices into the queue, shuffled when shuffle is on.
  List<int> get effectiveIndices;

  Future<void> setQueue(
    List<PlayableSong> items, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  });
  Future<void> insert(int index, PlayableSong item);
  Future<void> removeAt(int index);
  Future<void> move(int from, int to);

  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position, {int? index});
  Future<void> next();
  Future<void> previous();

  Future<void> setShuffle(bool enabled);
  Future<void> setRepeat(RepeatSetting mode);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);

  /// Null on platforms without a system equalizer (iOS).
  Future<EqualizerInfo?> equalizer();
  Future<void> setEqualizerEnabled(bool enabled);
  Future<void> setBandGain(int band, double gain);
  Future<void> setLoudnessBoost(double db);
}
