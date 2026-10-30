import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swara/data/catalog_repository.dart';
import 'package:swara/models/song.dart';

void main() {
  test('every built-in song has its audio and artwork assets', () {
    const songs = CatalogRepository.bundled;
    expect(songs, hasLength(10));
    expect(songs.map((s) => s.key).toSet(), hasLength(songs.length));
    for (final s in songs) {
      expect(s.source, SongSource.asset);
      for (final uri in [s.uri, s.artworkUrl!]) {
        final path = uri.replaceFirst('asset:///', '');
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    }
  });
}
