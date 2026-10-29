import 'package:flutter/material.dart';

import '../core/languages.dart';
import '../data/library_store.dart';

/// User preferences, persisted in the library store.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final LibraryStore _store;

  static const accents = <Color>[
    Color(0xFFFF6B35), // Saffron
    Color(0xFF1DB954), // Green
    Color(0xFFE91E63), // Rani pink
    Color(0xFF7C4DFF), // Violet
    Color(0xFF00B8D4), // Peacock blue
    Color(0xFFFFC107), // Turmeric
  ];

  ThemeMode get themeMode =>
      ThemeMode.values[_store.pref<int>('themeMode', ThemeMode.dark.index)];

  Color get accent =>
      accents[_store.pref<int>('accent', 0).clamp(0, accents.length - 1)];

  /// Ordered list of language codes; the first one drives the home feed.
  List<String> get languageCodes =>
      _store.pref<List>('languages', const ['te']).cast<String>();

  MusicLanguage get primaryLanguage => languageByCode(languageCodes.first);

  /// Never stream, even with a connection (saves mobile data).
  bool get offlineMode => _store.pref<bool>('offlineMode', false);

  double get loudnessBoost => _store.pref<double>('loudness', 0);
  bool get equalizerEnabled => _store.pref<bool>('eq', false);
  List<double> get equalizerGains =>
      _store.pref<List>('eqGains', const []).cast<double>();

  Future<void> _set(String key, Object value) async {
    await _store.setPref(key, value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) => _set('themeMode', mode.index);
  Future<void> setAccent(int index) => _set('accent', index);
  Future<void> setOfflineMode(bool value) => _set('offlineMode', value);
  Future<void> setLoudnessBoost(double db) => _set('loudness', db);
  Future<void> setEqualizerEnabled(bool value) => _set('eq', value);
  Future<void> setEqualizerGains(List<double> gains) => _set('eqGains', gains);

  Future<void> setPrimaryLanguage(String code) {
    final codes = [code, ...languageCodes.where((c) => c != code)];
    return _set('languages', codes);
  }

  Future<void> toggleLanguage(String code) {
    final codes = [...languageCodes];
    if (codes.contains(code)) {
      if (codes.length == 1) return Future.value();
      codes.remove(code);
    } else {
      codes.add(code);
    }
    return _set('languages', codes);
  }
}
