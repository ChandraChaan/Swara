import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';

enum LoopMode { off, all, one }

/// Owns the audio player, the play queue and the user's favourites.
class PlayerController extends ChangeNotifier {
  PlayerController({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _subscriptions.addAll([
      _player.onPlayerStateChanged.listen((state) {
        _isPlaying = state == PlayerState.playing;
        notifyListeners();
      }),
      _player.onPositionChanged.listen((p) {
        _position = p;
        notifyListeners();
      }),
      _player.onDurationChanged.listen((d) {
        _duration = d;
        notifyListeners();
      }),
      _player.onPlayerComplete.listen((_) => _onComplete()),
    ]);
  }

  static const _favouritesKey = 'favourites';

  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Random _random = Random();

  List<Track> _library = const [];
  List<Track> _queue = const [];
  int _index = -1;
  bool _isPlaying = false;
  bool _shuffle = false;
  LoopMode _repeat = LoopMode.all;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Set<String> _favourites = {};

  List<Track> get library => _library;
  List<Track> get queue => _queue;
  Track? get current =>
      _index >= 0 && _index < _queue.length ? _queue[_index] : null;
  bool get isPlaying => _isPlaying;
  bool get shuffle => _shuffle;
  LoopMode get repeat => _repeat;
  Duration get position => _position;
  Duration get duration => _duration;
  List<Track> get favourites =>
      _library.where((t) => _favourites.contains(t.id)).toList();

  bool isFavourite(Track track) => _favourites.contains(track.id);

  Future<void> init(List<Track> library) async {
    _library = library;
    _queue = library;
    final prefs = await SharedPreferences.getInstance();
    _favourites = (prefs.getStringList(_favouritesKey) ?? const []).toSet();
    notifyListeners();
  }

  /// Starts [track], making [queue] (defaults to the full library) the play queue.
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    _queue = List.unmodifiable(queue ?? _library);
    _index = _queue.indexWhere((t) => t.id == track.id);
    await _playCurrent();
  }

  Future<void> togglePlay() async {
    if (current == null) {
      if (_library.isNotEmpty) await playTrack(_library.first);
      return;
    }
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    if (_shuffle && _queue.length > 1) {
      var n = _index;
      while (n == _index) {
        n = _random.nextInt(_queue.length);
      }
      _index = n;
    } else {
      _index = (_index + 1) % _queue.length;
    }
    await _playCurrent();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    // Like most players: restart the song unless we're right at its start.
    if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    _index = (_index - 1 + _queue.length) % _queue.length;
    await _playCurrent();
  }

  Future<void> seek(Duration to) async {
    _position = to;
    notifyListeners();
    await _player.seek(to);
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void cycleRepeat() {
    _repeat = LoopMode.values[(_repeat.index + 1) % LoopMode.values.length];
    notifyListeners();
  }

  Future<void> toggleFavourite(Track track) async {
    if (!_favourites.remove(track.id)) _favourites.add(track.id);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favouritesKey, _favourites.toList());
  }

  Future<void> _playCurrent() async {
    final track = current;
    if (track == null) return;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
    await _player.stop();
    // AssetSource paths are relative to the `assets/` folder.
    await _player.play(
      AssetSource(track.audioAsset.replaceFirst('assets/', '')),
    );
  }

  Future<void> _onComplete() async {
    switch (_repeat) {
      case LoopMode.one:
        await _playCurrent();
      case LoopMode.all:
        await next();
      case LoopMode.off:
        if (_shuffle || _index < _queue.length - 1) {
          await next();
        } else {
          _isPlaying = false;
          _position = Duration.zero;
          notifyListeners();
        }
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
