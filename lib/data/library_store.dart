import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';

import '../models/collection.dart';
import '../models/song.dart';

/// A downloaded song and where its files live on disk.
class DownloadRecord {
  const DownloadRecord({
    required this.song,
    required this.path,
    required this.bytes,
    required this.downloadedAt,
    this.artworkPath,
  });

  final Song song;
  final String path;
  final String? artworkPath;
  final int bytes;
  final DateTime downloadedAt;

  /// The song as it should be shown and played offline.
  Song get offlineSong => song.copyWith(artworkUrl: artworkPath);

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'path': path,
    if (artworkPath != null) 'artworkPath': artworkPath,
    'bytes': bytes,
    'at': downloadedAt.millisecondsSinceEpoch,
  };

  factory DownloadRecord.fromJson(Map<dynamic, dynamic> json) => DownloadRecord(
    song: Song.fromJson(json['song'] as Map),
    path: json['path'] as String,
    artworkPath: json['artworkPath'] as String?,
    bytes: json['bytes'] as int? ?? 0,
    downloadedAt: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
  );
}

/// Everything the user owns: likes, playlists, downloads, imported device
/// songs, listening history and recent searches. Backed by Hive so it is
/// fully available offline.
class LibraryStore extends ChangeNotifier {
  LibraryStore._(
    this._liked,
    this._downloads,
    this._playlists,
    this._device,
    this._meta,
  );

  static const historyLimit = 200;
  static const recentSearchLimit = 12;

  static Future<LibraryStore> open() async {
    return LibraryStore._(
      await Hive.openBox('liked'),
      await Hive.openBox('downloads'),
      await Hive.openBox('playlists'),
      await Hive.openBox('device'),
      await Hive.openBox('meta'),
    );
  }

  final Box _liked;
  final Box _downloads;
  final Box _playlists;
  final Box _device;
  final Box _meta;

  // ----------------------------------------------------------------- likes

  bool isLiked(Song song) => _liked.containsKey(song.key);

  List<Song> get likedSongs {
    final entries = _liked.values.cast<Map>().toList()
      ..sort((a, b) => (b['at'] as int).compareTo(a['at'] as int));
    return entries.map((e) => Song.fromJson(e['song'] as Map)).toList();
  }

  Future<void> toggleLike(Song song) async {
    if (isLiked(song)) {
      await _liked.delete(song.key);
    } else {
      await _liked.put(song.key, {
        'song': song.toJson(),
        'at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    notifyListeners();
  }

  // ------------------------------------------------------------- downloads

  DownloadRecord? download(Song song) {
    final raw = _downloads.get(song.key);
    return raw == null ? null : DownloadRecord.fromJson(raw as Map);
  }

  bool isDownloaded(Song song) => _downloads.containsKey(song.key);

  List<DownloadRecord> get downloads {
    final list =
        _downloads.values.cast<Map>().map(DownloadRecord.fromJson).toList()
          ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return list;
  }

  int get downloadedBytes =>
      downloads.fold(0, (sum, record) => sum + record.bytes);

  Future<void> saveDownload(DownloadRecord record) async {
    await _downloads.put(record.song.key, record.toJson());
    notifyListeners();
  }

  Future<void> removeDownloadRecord(Song song) async {
    await _downloads.delete(song.key);
    notifyListeners();
  }

  // ------------------------------------------------------------- playlists

  List<UserPlaylist> get playlists {
    return _playlists.values.cast<Map>().map(UserPlaylist.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  UserPlaylist? playlist(String id) {
    final raw = _playlists.get(id);
    return raw == null ? null : UserPlaylist.fromJson(raw as Map);
  }

  Future<UserPlaylist> createPlaylist(String name, [List<Song>? songs]) async {
    final id =
        '${DateTime.now().microsecondsSinceEpoch}'
        '${Random().nextInt(1 << 16)}';
    final playlist = UserPlaylist(id: id, name: name.trim(), songs: songs);
    await _playlists.put(id, playlist.toJson());
    notifyListeners();
    return playlist;
  }

  Future<void> savePlaylist(UserPlaylist playlist) async {
    await _playlists.put(playlist.id, playlist.toJson());
    notifyListeners();
  }

  /// Returns false when the song was already in the playlist.
  Future<bool> addToPlaylist(String playlistId, Song song) async {
    final p = playlist(playlistId);
    if (p == null || p.songs.contains(song)) return false;
    p.songs.add(song);
    await savePlaylist(p);
    return true;
  }

  Future<void> deletePlaylist(String id) async {
    await _playlists.delete(id);
    notifyListeners();
  }

  // ---------------------------------------------------------- device songs

  List<Song> get deviceSongs =>
      _device.values.cast<Map>().map(Song.fromJson).toList()..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

  Future<void> addDeviceSongs(Iterable<Song> songs) async {
    await _device.putAll({for (final s in songs) s.key: s.toJson()});
    notifyListeners();
  }

  Future<void> removeDeviceSong(Song song) async {
    await _device.delete(song.key);
    notifyListeners();
  }

  // --------------------------------------------------------------- history

  List<Song> get history => ((_meta.get('history') as List?) ?? const [])
      .cast<Map>()
      .map(Song.fromJson)
      .toList();

  Future<void> addToHistory(Song song) async {
    final list = history..remove(song);
    list.insert(0, song);
    await _meta.put(
      'history',
      list.take(historyLimit).map((s) => s.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _meta.delete('history');
    notifyListeners();
  }

  /// Artists the user listens to most, used to personalise the home feed.
  List<String> topArtists({int limit = 5}) {
    final counts = <String, int>{};
    for (final s in history) {
      if (s.artist.isEmpty || s.artist.startsWith('Unknown')) continue;
      // Built-in tracks don't have an artist worth searching online for.
      if (s.source == SongSource.asset) continue;
      counts[s.artist] = (counts[s.artist] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  // ------------------------------------------------------- recent searches

  List<String> get recentSearches =>
      ((_meta.get('recentSearches') as List?) ?? const []).cast<String>();

  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list =
        recentSearches.where((s) => s.toLowerCase() != q.toLowerCase()).toList()
          ..insert(0, q);
    await _meta.put('recentSearches', list.take(recentSearchLimit).toList());
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    await _meta.delete('recentSearches');
    notifyListeners();
  }

  // ------------------------------------------------------- session & prefs

  Map? get lastSession => _meta.get('session') as Map?;

  Future<void> saveSession(List<Song> queue, int index, Duration position) =>
      _meta.put('session', {
        'queue': queue.map((s) => s.toJson()).toList(),
        'index': index,
        'positionMs': position.inMilliseconds,
      });

  T pref<T>(String key, T fallback) =>
      (_meta.get('pref:$key') as T?) ?? fallback;

  Future<void> setPref(String key, Object value) async {
    await _meta.put('pref:$key', value);
    notifyListeners();
  }
}
