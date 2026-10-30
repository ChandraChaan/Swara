import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_controller.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/search_screen.dart';
import 'widgets/mini_player.dart';

/// Bottom navigation with one navigator per tab, so each tab keeps its own
/// history and the mini player stays visible everywhere.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _navigators = List.generate(3, (_) => GlobalKey<NavigatorState>());
  StreamSubscription<String>? _messages;

  static const _roots = <Widget>[HomeScreen(), SearchScreen(), LibraryScreen()];

  @override
  void initState() {
    super.initState();
    _messages = context.read<PlayerController>().messages.listen((m) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(m)));
    });
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  void _select(int index) {
    if (index == _tab) {
      // Tapping the active tab returns to its root, like every big app.
      _navigators[index].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _tab = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = _navigators[_tab].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab,
          children: [
            for (var i = 0; i < _roots.length; i++)
              HeroMode(
                enabled: i == _tab,
                child: Navigator(
                  key: _navigators[i],
                  onGenerateRoute: (_) =>
                      MaterialPageRoute<void>(builder: (_) => _roots[i]),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _select,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.manage_search_rounded),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
