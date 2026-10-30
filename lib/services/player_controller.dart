import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/library_store.dart';
import '../models/song.dart';
import 'audio_engine.dart';

/// UI-facing playback state: the queue, the current song, shuffle/repeat,
/// speed and the sleep timer. Audio itself is handled by an [AudioEngine].
class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.engine,
    required this.store,
    required bool Function() isOnline,
  }) : _isOnline = isOnline {
    _subs.addAll([
      engine.playingStream.listen((p) {
        if (p == _playing) return;
        _playing = p;
        if (!p) _saveSession();
        notifyListeners();
      }),
      engine.stateStream.listen((s) {
        _state = s;
        notifyListeners();
      }),
      engine.durationStream.listen((d) {
        _duration = d;
        notifyListeners();
      }),
      engine.currentIndexStream.listen(_onIndex),
      engine.errorStream.listen(_messages.add),
    ]);
    _sessionTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_playing) _saveSession();
    });
  }

  final AudioEngine engine;
  final LibraryStore store;
  final bool Function() _isOnline;
  final _subs = <StreamSubscription<dynamic>>[];
  final _messages = StreamController<String>.broadcast();
  Timer? _sessionTimer;

  List<Song> _queue = const [];
  int? _index;
  bool _playing = false;
  EngineState _state = EngineState.idle;
  Duration? _duration;
  bool _shuffle = false;
  RepeatSetting _repeat = RepeatSetting.off;
  double _speed = 1.0;
  String? _lastHistoryKey;

  Timer? _sleepTimer;
  DateTime? _sleepAt;
  bool _sleepAtEndOfSong = false;

  List<Song> get queue => List.unmodifiable(_queue);
  int? get index => _index;
  Song? get current =>
      _index != null && _index! < _queue.length ? _queue[_index!] : null;
  bool get playing => _playing;
  bool get buffering =>
      _state == EngineState.loading || _state == EngineState.buffering;
  EngineState get state => _state;
  Duration? get duration => _duration ?? current?.duration;
  bool get shuffle => _shuffle;
  RepeatSetting get repeat => _repeat;
  double get speed => _speed;
  Stream<Duration> get positionStream => engine.positionStream;
  Stream<Duration> get bufferedStream => engine.bufferedPositionStream;
  Duration get position => engine.position;

  /// User-facing messages (errors, skipped songs) shown as snack bars.
  Stream<String> get messages => _messages.stream;

  /// The queue in the order it will be played, starting with the current
  /// song.
  List<(int, Song)> get upNext {
    final order = engine.effectiveIndices;
    final indices = order.length == _queue.length
        ? order
        : List.generate(_queue.length, (i) => i);
    final start = _index == null ? 0 : indices.indexOf(_index!);
    return [
      for (final i in indices.skip(start < 0 ? 0 : start)) (i, _queue[i]),
    ];
  }

  bool canPlay(Song song) =>
      !song.source.isOnline || store.isDownloaded(song) || _isOnline();

  /// Prefers the downloaded file over streaming whenever one exists.
  PlayableSong _playable(Song song) {
    final record = store.download(song);
    if (record != null) return PlayableSong(record.offlineSong, record.path);
    return PlayableSong(song, song.uri);
  }

  void _onIndex(int? i) {
    _index = i;
    final song = current;
    if (song != null && song.key != _lastHistoryKey) {
      if (_lastHistoryKey != null && _sleepAtEndOfSong) {
        _sleepAtEndOfSong = false;
        engine.pause();
        engine.seek(Duration.zero);
      }
      _lastHistoryKey = song.key;
      store.addToHistory(song);
      _saveSession();
    }
    notifyListeners();
  }

  /// Replaces the queue with [songs] and starts at [startIndex]. Songs that
  /// cannot play right now (online, not downloaded, no connection) are left
  /// out. Returns the number of songs that were skipped.
  Future<int> playSongs(
    List<Song> songs, {
    int startIndex = 0,
    bool shuffle = false,
    bool autoplay = true,
  }) async {
    if (songs.isEmpty) return 0;
    final start = songs[startIndex.clamp(0, songs.length - 1)];
    final playable = songs.where(canPlay).toList();
    final skipped = songs.length - playable.length;
    if (playable.isEmpty) {
      _messages.add("You're offline. Download songs to play them anytime.");
      return skipped;
    }
    var index = playable.indexOf(start);
    if (index < 0) index = 0;
    if (shuffle) {
      index = (DateTime.now().microsecondsSinceEpoch % playable.length);
    }
    final items = playable.map(_playable).toList();
    _queue = items.map((p) => p.song).toList();
    _index = index;
    _duration = null;
    notifyListeners();
    await engine.setQueue(items, initialIndex: index);
    // "Shuffle play" turns shuffle on; a plain play keeps the user's choice.
    if (shuffle || _shuffle) await setShuffle(true);
    if (autoplay) unawaited(engine.play());
    if (skipped > 0) {
      _messages.add(
        '$skipped song${skipped == 1 ? '' : 's'} skipped '
        '(not downloaded, offline)',
      );
    }
    return skipped;
  }

  Future<void> playSong(Song song) => playSongs([song]);

  Future<void> togglePlay() async {
    if (current == null) return;
    if (_playing) {
      await engine.pause();
    } else {
      if (_state == EngineState.completed) await engine.seek(Duration.zero);
      await engine.play();
    }
  }

  Future<void> next() => engine.next();
  Future<void> previous() => engine.previous();
  Future<void> seek(Duration position) => engine.seek(position);

  Future<void> jumpTo(int queueIndex) async {
    await engine.seek(Duration.zero, index: queueIndex);
    if (!_playing) await engine.play();
  }

  Future<void> playNext(Song song) async {
    if (!canPlay(song)) {
      _messages.add("You're offline. Download this song to play it.");
      return;
    }
    if (_queue.isEmpty) return playSong(song);
    final existing = _queue.indexOf(song);
    if (existing >= 0 && existing != _index) await removeAt(existing);
    if (existing == _index) return;
    final at = (_index ?? -1) + 1;
    _queue = [..._queue]..insert(at, _playable(song).song);
    notifyListeners();
    await engine.insert(at, _playable(song));
    _messages.add('Playing "${song.title}" next');
  }

  Future<void> addToQueue(Song song) async {
    if (!canPlay(song)) {
      _messages.add("You're offline. Download this song to play it.");
      return;
    }
    if (_queue.isEmpty) return playSong(song);
    if (_queue.contains(song)) {
      _messages.add('Already in queue');
      return;
    }
    final at = _queue.length;
    _queue = [..._queue, _playable(song).song];
    notifyListeners();
    await engine.insert(at, _playable(song));
    _messages.add('Added "${song.title}" to queue');
  }

  Future<void> removeAt(int queueIndex) async {
    if (queueIndex == _index) return;
    _queue = [..._queue]..removeAt(queueIndex);
    if (_index != null && queueIndex < _index!) _index = _index! - 1;
    notifyListeners();
    await engine.removeAt(queueIndex);
  }

  Future<void> move(int from, int to) async {
    if (from == to) return;
    final current = this.current;
    final list = [..._queue];
    list.insert(to, list.removeAt(from));
    _queue = list;
    if (current != null) _index = list.indexOf(current);
    notifyListeners();
    await engine.move(from, to);
  }

  Future<void> setShuffle(bool enabled) async {
    _shuffle = enabled;
    notifyListeners();
    await engine.setShuffle(enabled);
  }

  Future<void> cycleRepeat() async {
    _repeat =
        RepeatSetting.values[(_repeat.index + 1) % RepeatSetting.values.length];
    notifyListeners();
    await engine.setRepeat(_repeat);
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    notifyListeners();
    await engine.setSpeed(speed);
  }

  // ------------------------------------------------------------ sleep timer

  /// Time left on the sleep timer, or null when it is off or set to the end
  /// of the current song.
  Duration? get sleepRemaining {
    final at = _sleepAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get sleepAtEndOfSong => _sleepAtEndOfSong;
  bool get sleepTimerActive => _sleepAt != null || _sleepAtEndOfSong;

  void setSleepTimer(Duration? duration, {bool endOfSong = false}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepAt = null;
    _sleepAtEndOfSong = endOfSong;
    engine.setVolume(1);
    if (duration != null) {
      _sleepAt = DateTime.now().add(duration);
      _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final left = sleepRemaining!;
        // Fade out gently over the last ten seconds.
        if (left <= const Duration(seconds: 10)) {
          engine.setVolume(left.inMilliseconds / 10000);
        }
        if (left == Duration.zero) {
          engine.pause();
          setSleepTimer(null);
          _messages.add('Sleep timer ended. Good night!');
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // --------------------------------------------------------------- session

  void _saveSession() {
    final i = _index;
    if (i == null || _queue.isEmpty) return;
    store.saveSession(_queue, i, engine.position);
  }

  /// Restores the last queue and position without starting playback, so the
  /// mini player is ready the moment the app opens.
  Future<void> restoreSession() async {
    final session = store.lastSession;
    if (session == null) return;
    try {
      final songs = (session['queue'] as List)
          .cast<Map>()
          .map(Song.fromJson)
          .where(canPlay)
          .toList();
      if (songs.isEmpty) return;
      final index = (session['index'] as int).clamp(0, songs.length - 1);
      final items = songs.map(_playable).toList();
      _queue = items.map((p) => p.song).toList();
      _index = index;
      _lastHistoryKey = _queue[index].key;
      notifyListeners();
      await engine.setQueue(
        items,
        initialIndex: index,
        initialPosition: Duration(
          milliseconds: session['positionMs'] as int? ?? 0,
        ),
      );
    } catch (_) {
      // A corrupt session must never block startup.
    }
  }

  @override
  void dispose() {
    _saveSession();
    for (final s in _subs) {
      s.cancel();
    }
    _sessionTimer?.cancel();
    _sleepTimer?.cancel();
    _messages.close();
    super.dispose();
  }
}
