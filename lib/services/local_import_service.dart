import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';

import '../data/library_store.dart';
import '../models/song.dart';

/// Imports music files the user already has (for example a folder of Telugu
/// MP3s) into the app library so they play offline with full metadata.
class LocalImportService {
  LocalImportService({
    required this.store,
    required Future<Directory> Function() directory,
  }) : _directory = directory;

  final LibraryStore store;
  final Future<Directory> Function() _directory;

  /// Opens the system picker and imports the chosen files. Returns the
  /// number of songs added.
  Future<int> pickAndImport() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Choose songs to add',
      type: FileType.audio,
    );
    if (files.isEmpty) return 0;

    final dir = Directory('${(await _directory()).path}/imported');
    await dir.create(recursive: true);
    final songs = <Song>[];
    for (final file in files) {
      final song = await _import(file, dir);
      if (song != null) songs.add(song);
    }
    await store.addDeviceSongs(songs);
    return songs.length;
  }

  Future<Song?> _import(PlatformFile picked, Directory dir) async {
    try {
      final safe = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
      final target = File('${dir.path}/$safe');
      if (!await target.exists()) await picked.xFile.saveTo(target.path);
      return await songFromFile(target);
    } catch (_) {
      return null; // Skip unreadable files, import the rest.
    }
  }

  /// Builds a [Song] from a file's tags, falling back to the file name.
  static Future<Song> songFromFile(File file) async {
    final name = file.uri.pathSegments.last;
    final stem = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    String title = stem.replaceAll('_', ' ');
    String artist = 'Unknown artist';
    String album = '';
    Duration? duration;
    String? artPath;
    try {
      final meta = readMetadata(file, getImage: true);
      title = cleanTitle(meta.title ?? title);
      artist = meta.artist ?? meta.albumArtist ?? artist;
      album = meta.album ?? '';
      duration = meta.duration;
      if (meta.pictures.isNotEmpty) {
        final art = File('${file.path}.art');
        await art.writeAsBytes(meta.pictures.first.bytes);
        artPath = art.path;
      }
    } catch (_) {
      // Untagged or unusual files still import with their file name.
    }
    return Song(
      id: file.path,
      source: SongSource.device,
      title: title,
      artist: artist,
      album: album,
      uri: file.path,
      artworkUrl: artPath,
      duration: duration,
    );
  }

  /// Removes common download-site prefixes such as `[SiteName] 01 - `.
  static String cleanTitle(String raw) => raw
      .replaceFirst(RegExp(r'^\s*\[[^\]]*\]\s*'), '')
      .replaceFirst(RegExp(r'^\d{1,3}\s*[-.]\s*'), '')
      .trim();
}
