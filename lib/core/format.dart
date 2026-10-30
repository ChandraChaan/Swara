String formatDuration(Duration? d) {
  if (d == null) return '--:--';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

/// Time-of-day greeting in English with the Telugu equivalent.
String greeting(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning • శుభోదయం';
  if (h < 17) return 'Good afternoon • శుభ మధ్యాహ్నం';
  return 'Good evening • శుభ సాయంత్రం';
}

/// Parses durations like `245.3`, `4:05` or `1:02:03` as returned by the
/// Internet Archive metadata API.
Duration? parseLooseDuration(Object? value) {
  if (value == null) return null;
  if (value is num) return Duration(milliseconds: (value * 1000).round());
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  if (!s.contains(':')) {
    final seconds = double.tryParse(s);
    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
  }
  var total = 0.0;
  for (final part in s.split(':')) {
    final v = double.tryParse(part);
    if (v == null) return null;
    total = total * 60 + v;
  }
  return Duration(milliseconds: (total * 1000).round());
}
