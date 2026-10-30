import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/track.dart';
import 'player/player_controller.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = PlayerController();
  await controller.init(await Track.loadCatalog(rootBundle));
  runApp(
    ChangeNotifierProvider.value(value: controller, child: const SwaraApp()),
  );
}

class SwaraApp extends StatelessWidget {
  const SwaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swara',
      debugShowCheckedModeBanner: false,
      theme: SwaraTheme.light(),
      darkTheme: SwaraTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const HomeShell(),
    );
  }
}
