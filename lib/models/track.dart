import 'dart:convert';

import 'package:flutter/services.dart';

/// A song bundled with the app, described by `assets/catalog.json`.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.raga,
    required this.instrument,
    required this.tala,
    required this.bpm,
    required this.audioAsset,
    required this.coverAsset,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String,
    raga: json['raga'] as String,
    instrument: json['instrument'] as String,
    tala: json['tala'] as String,
    bpm: json['bpm'] as int,
    audioAsset: json['audio'] as String,
    coverAsset: json['cover'] as String,
  );

  final String id;
  final String title;
  final String artist;
  final String album;
  final String raga;
  final String instrument;
  final String tala;
  final int bpm;
  final String audioAsset;
  final String coverAsset;

  String get instrumentLabel =>
      instrument[0].toUpperCase() + instrument.substring(1);

  String get subtitle => 'Raga $raga · $instrumentLabel';

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      title,
      raga,
      instrument,
      tala,
      artist,
    ].any((field) => field.toLowerCase().contains(q));
  }

  static Future<List<Track>> loadCatalog(AssetBundle bundle) async {
    final raw = await bundle.loadString('assets/catalog.json');
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
