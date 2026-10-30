import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/library_store.dart';
import '../models/song.dart';

enum DownloadStatus { queued, downloading, failed }

class DownloadTask {
  DownloadTask(this.song);

  final Song song;
  DownloadStatus status = DownloadStatus.queued;
  int received = 0;
  int? total;
  String? error;
  bool cancelled = false;

  double? get progress =>
      total == null || total == 0 ? null : (received / total!).clamp(0, 1);
}

/// Saves online songs (and their artwork) into the app's private storage so
/// they can be played without a connection, like offline mode in Spotify or
/// Gaana.
class DownloadManager extends ChangeNotifier {
  DownloadManager({
    required this.store,
    required Future<Directory> Function() directory,
    http.Client? client,
    this.maxConcurrent = 2,
  }) : _directory = directory,
       _client = client ?? http.Client();

  final LibraryStore store;
  final Future<Directory> Function() _directory;
  final http.Client _client;
  final int maxConcurrent;

  final _tasks = <String, DownloadTask>{};
  int _active = 0;

  List<DownloadTask> get tasks => _tasks.values.toList();
  DownloadTask? task(Song song) => _tasks[song.key];
  bool isBusy(Song song) => _tasks.containsKey(song.key);

  static bool canDownload(Song song) => song.source.isOnline;

  /// Queues [songs] that are online and not downloaded yet. Returns how many
  /// were queued.
  int enqueue(Iterable<Song> songs) {
    var added = 0;
    for (final song in songs) {
      if (!canDownload(song) ||
          store.isDownloaded(song) ||
          _tasks.containsKey(song.key)) {
        continue;
      }
      _tasks[song.key] = DownloadTask(song);
      added++;
    }
    if (added > 0) {
      notifyListeners();
      _pump();
    }
    return added;
  }

  void cancel(Song song) {
    final t = _tasks[song.key];
    if (t == null) return;
    t.cancelled = true;
    if (t.status != DownloadStatus.downloading) _tasks.remove(song.key);
    notifyListeners();
  }

  void retry(Song song) {
    final t = _tasks[song.key];
    if (t == null || t.status != DownloadStatus.failed) return;
    t
      ..status = DownloadStatus.queued
      ..error = null
      ..received = 0;
    notifyListeners();
    _pump();
  }

  Future<void> delete(Song song) async {
    final record = store.download(song);
    if (record == null) return;
    for (final path in [record.path, record.artworkPath]) {
      if (path == null) continue;
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    await store.removeDownloadRecord(song);
  }

  Future<void> deleteAll() async {
    for (final r in store.downloads) {
      await delete(r.song);
    }
  }

  void _pump() {
    while (_active < maxConcurrent) {
      final next = _tasks.values
          .where((t) => t.status == DownloadStatus.queued)
          .firstOrNull;
      if (next == null) return;
      _active++;
      next.status = DownloadStatus.downloading;
      notifyListeners();
      _run(next).whenComplete(() {
        _active--;
        _pump();
      });
    }
  }

  static String _safeName(String key) =>
      key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static String _extension(String url, String? contentType) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final ext in ['.mp3', '.m4a', '.aac', '.ogg', '.opus', '.flac']) {
      if (path.endsWith(ext)) return ext;
    }
    if (contentType != null) {
      if (contentType.contains('mp4') || contentType.contains('aac')) {
        return '.m4a';
      }
      if (contentType.contains('ogg')) return '.ogg';
    }
    return '.mp3';
  }

  Future<void> _run(DownloadTask task) async {
    final dir = Directory('${(await _directory()).path}/downloads');
    await dir.create(recursive: true);
    final song = task.song;
    final base = '${dir.path}/${_safeName(song.key)}';
    File? partial;
    try {
      final res = await _client.send(http.Request('GET', Uri.parse(song.uri)));
      if (res.statusCode != 200) {
        throw HttpException('Server returned ${res.statusCode}');
      }
      task.total = res.contentLength;
      final ext = _extension(song.uri, res.headers['content-type']);
      partial = File('$base$ext.part');
      final sink = partial.openWrite();
      var lastNotify = DateTime.now();
      try {
        await for (final chunk in res.stream) {
          if (task.cancelled) throw const _Cancelled();
          sink.add(chunk);
          task.received += chunk.length;
          if (DateTime.now().difference(lastNotify) >
              const Duration(milliseconds: 250)) {
            lastNotify = DateTime.now();
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      final audio = await partial.rename('$base$ext');
      final artworkPath = await _saveArtwork(song, base);
      await store.saveDownload(
        DownloadRecord(
          song: song,
          path: audio.path,
          artworkPath: artworkPath,
          bytes: await audio.length(),
          downloadedAt: DateTime.now(),
        ),
      );
      _tasks.remove(song.key);
    } on _Cancelled {
      _tasks.remove(song.key);
    } catch (e) {
      task
        ..status = DownloadStatus.failed
        ..error = e.toString();
    } finally {
      if (partial != null && await partial.exists()) await partial.delete();
      notifyListeners();
    }
  }

  Future<String?> _saveArtwork(Song song, String base) async {
    final url = song.artworkUrl;
    if (url == null || !url.startsWith('http')) return null;
    try {
      final res = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final file = File('$base.art');
      await file.writeAsBytes(res.bodyBytes);
      return file.path;
    } catch (_) {
      return null; // Artwork is optional.
    }
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
