import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has a network connection. The app switches to
/// its offline experience automatically when the connection drops.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({
    Stream<bool>? changes,
    Future<bool> Function()? check,
    bool initial = true,
  }) : _online = initial {
    _check = check ?? _defaultCheck;
    _sub = (changes ?? _defaultChanges()).listen(_set);
    _check().then(_set).catchError((_) {});
  }

  late final Future<bool> Function() _check;
  late final StreamSubscription<bool> _sub;
  bool _online;

  bool get online => _online;

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  static Future<bool> _defaultCheck() async =>
      _hasNetwork(await Connectivity().checkConnectivity());

  static Stream<bool> _defaultChanges() =>
      Connectivity().onConnectivityChanged.map(_hasNetwork);

  void _set(bool value) {
    if (value == _online) return;
    _online = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
