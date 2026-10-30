import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'settings_controller.dart';

/// Whether online content may be used right now: there is a connection and
/// the user has not switched on offline mode.
class AppState extends ChangeNotifier {
  AppState(this._connectivity, this._settings) {
    _online = online;
    _connectivity.addListener(_update);
    _settings.addListener(_update);
  }

  final ConnectivityService _connectivity;
  final SettingsController _settings;
  late bool _online;

  bool get online => _connectivity.online && !_settings.offlineMode;

  void _update() {
    if (online == _online) return;
    _online = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivity.removeListener(_update);
    _settings.removeListener(_update);
    super.dispose();
  }
}
