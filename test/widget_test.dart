import 'dart:io';

import 'package:swara/data/catalog_repository.dart';
import 'package:swara/data/library_store.dart';
import 'package:swara/data/lyrics_service.dart';
import 'package:swara/main.dart';
import 'package:swara/services/app_state.dart';
import 'package:swara/services/connectivity_service.dart';
import 'package:swara/services/download_manager.dart';
import 'package:swara/services/local_import_service.dart';
import 'package:swara/services/player_controller.dart';
import 'package:swara/services/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late LibraryStore store;
  late FakeEngine engine;
  late PlayerController player;

  setUp(() async {
    store = await openTempStore();
    engine = FakeEngine();
  });

  tearDown(closeTempStore);

  Widget app() {
    final settings = SettingsController(store);
    final connectivity = ConnectivityService(
      changes: const Stream.empty(),
      check: () async => false,
      initial: false,
    );
    final appState = AppState(connectivity, settings);
    player = PlayerController(
      engine: engine,
      store: store,
      isOnline: () => appState.online,
    );
    return SwaraApp(
      store: store,
      settings: settings,
      connectivity: connectivity,
      appState: appState,
      player: player,
      downloads: DownloadManager(
        store: store,
        directory: () async => Directory.systemTemp,
      ),
      catalog: CatalogRepository(sources: const []),
      lyrics: LyricsService(),
      importer: LocalImportService(
        store: store,
        directory: () async => Directory.systemTemp,
      ),
    );
  }

  testWidgets('offline home plays bundled raga tracks', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.textContaining('శుభ'), findsOneWidget);
    expect(find.text('Telugu • తెలుగు'), findsOneWidget);
    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(find.text('Your offline music'), findsOneWidget);
    expect(find.text('Mohanam Dawn'), findsOneWidget);

    await tester.tap(find.text('Mohanam Dawn'));
    await tester.pump();

    expect(
      engine.items.first.location,
      'asset:///assets/audio/mohanam_dawn.mp3',
    );
    expect(engine.calls, contains('play'));
    // The mini player now shows the song too.
    expect(find.text('Mohanam Dawn'), findsNWidgets(2));
    expect(find.byTooltip('Like'), findsOneWidget);
    // Let artwork colour extraction time out (no real images in tests).
    await tester.pump(const Duration(seconds: 6));
    await tester.runAsync(() async => player.dispose());
  });

  testWidgets('navigates between tabs', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Your Library'), findsOneWidget);
    expect(find.text('Liked Songs'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('On this device'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Browse all'), findsOneWidget);
    expect(find.text('Search your offline library'), findsOneWidget);

    // Offline search finds bundled songs.
    await tester.enterText(find.byType(TextField), 'veena');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('In your library'), findsOneWidget);
    expect(find.text('Hamsadhwani Flight'), findsOneWidget);
    expect(find.text('Hindolam Moon'), findsOneWidget);
    await tester.runAsync(() async => player.dispose());
  });
}
