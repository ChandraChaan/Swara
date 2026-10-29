import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/catalog_repository.dart';
import 'data/library_store.dart';
import 'data/lyrics_service.dart';
import 'services/app_state.dart';
import 'services/audio_engine.dart';
import 'services/audio_handler.dart';
import 'services/connectivity_service.dart';
import 'services/download_manager.dart';
import 'services/local_import_service.dart';
import 'services/player_controller.dart';
import 'services/settings_controller.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final store = await LibraryStore.open();
  final settings = SettingsController(store);
  final connectivity = ConnectivityService();
  final appState = AppState(connectivity, settings);
  final engine = await AppAudioHandler.create();
  final player = PlayerController(
    engine: engine,
    store: store,
    isOnline: () => appState.online,
  );
  final downloads = DownloadManager(
    store: store,
    directory: getApplicationDocumentsDirectory,
  );

  _restoreSoundSettings(engine, settings);
  unawaited(player.restoreSession());

  runApp(
    SwaraApp(
      store: store,
      settings: settings,
      connectivity: connectivity,
      appState: appState,
      player: player,
      downloads: downloads,
      catalog: CatalogRepository(),
      lyrics: LyricsService(),
      importer: LocalImportService(
        store: store,
        directory: getApplicationDocumentsDirectory,
      ),
    ),
  );
}

/// The Android equalizer only accepts settings once audio has loaded, so
/// saved settings are applied when the first song becomes ready.
void _restoreSoundSettings(AudioEngine engine, SettingsController settings) {
  if (!Platform.isAndroid) return;
  late StreamSubscription<EngineState> sub;
  sub = engine.stateStream.listen((state) async {
    if (state != EngineState.ready) return;
    await sub.cancel();
    if (settings.loudnessBoost > 0) {
      await engine.setLoudnessBoost(settings.loudnessBoost);
    }
    if (!settings.equalizerEnabled) return;
    await engine.setEqualizerEnabled(true);
    final gains = settings.equalizerGains;
    for (var i = 0; i < gains.length; i++) {
      await engine.setBandGain(i, gains[i]);
    }
  });
}

class SwaraApp extends StatelessWidget {
  const SwaraApp({
    super.key,
    required this.store,
    required this.settings,
    required this.connectivity,
    required this.appState,
    required this.player,
    required this.downloads,
    required this.catalog,
    required this.lyrics,
    required this.importer,
  });

  final LibraryStore store;
  final SettingsController settings;
  final ConnectivityService connectivity;
  final AppState appState;
  final PlayerController player;
  final DownloadManager downloads;
  final CatalogRepository catalog;
  final LyricsService lyrics;
  final LocalImportService importer;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: connectivity),
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider.value(value: downloads),
        Provider.value(value: catalog),
        Provider.value(value: lyrics),
        Provider.value(value: importer),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Swara',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: AppTheme.build(settings.accent, Brightness.light),
          darkTheme: AppTheme.build(settings.accent, Brightness.dark),
          home: const Shell(),
        ),
      ),
    );
  }
}
