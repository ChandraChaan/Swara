import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swara/models/track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog lists ten tracks whose audio and cover assets exist', () async {
    final tracks = await Track.loadCatalog(rootBundle);
    expect(tracks, hasLength(10));
    expect(
      tracks.map((t) => t.id).toSet(),
      hasLength(10),
      reason: 'ids must be unique',
    );
    for (final t in tracks) {
      expect(
        (await rootBundle.load(t.audioAsset)).lengthInBytes,
        greaterThan(0),
      );
      expect(
        (await rootBundle.load(t.coverAsset)).lengthInBytes,
        greaterThan(0),
      );
    }
  });

  test('search matches title, raga and instrument case-insensitively', () {
    const track = Track(
      id: 'x',
      title: 'Mohanam Dawn',
      artist: 'Swara Ensemble',
      album: 'Demo',
      raga: 'Mohanam',
      instrument: 'flute',
      tala: 'Keherwa',
      bpm: 84,
      audioAsset: 'a.mp3',
      coverAsset: 'a.jpg',
    );
    expect(track.matches('dawn'), isTrue);
    expect(track.matches('MOHAN'), isTrue);
    expect(track.matches('flute'), isTrue);
    expect(track.matches('  '), isTrue);
    expect(track.matches('veena'), isFalse);
    expect(track.subtitle, 'Raga Mohanam · Flute');
  });
}
