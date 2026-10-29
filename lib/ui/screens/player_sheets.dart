import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/lyrics_service.dart';
import '../../models/lyrics.dart';
import '../../models/song.dart';
import '../../services/audio_engine.dart';
import '../../services/player_controller.dart';
import '../../services/settings_controller.dart';
import '../widgets/artwork.dart';

Future<void> _sheet(
  BuildContext context,
  Widget child, {
  double heightFactor = 0.85,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        FractionallySizedBox(heightFactor: heightFactor, child: child),
  );
}

// ------------------------------------------------------------------ queue

void showQueueSheet(BuildContext context) =>
    _sheet(context, const _QueueSheet());

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final queue = player.queue;
    final current = player.current;
    final upNext = player.upNext.skip(1).toList();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Now playing', style: theme.textTheme.titleMedium),
          ),
          ListTile(
            leading: Artwork(
              url: current.artworkUrl,
              size: 48,
              seed: current.key,
            ),
            title: Text(
              current.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            subtitle: Text(current.artist, maxLines: 1),
            trailing: Icon(
              Icons.graphic_eq_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Next up • ${upNext.length}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (player.shuffle)
                const Chip(
                  avatar: Icon(Icons.shuffle_rounded, size: 16),
                  label: Text('Shuffle on'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        Expanded(
          child: player.shuffle
              // In shuffle mode the play order differs from the list order,
              // so dragging to reorder would be confusing.
              ? ListView(
                  children: [
                    for (final (i, song) in upNext)
                      _QueueTile(key: ValueKey(song.key), index: i, song: song),
                  ],
                )
              : ReorderableListView.builder(
                  itemCount: queue.length - (player.index ?? -1) - 1,
                  onReorderItem: (from, to) {
                    final base = (player.index ?? -1) + 1;
                    player.move(base + from, base + to);
                  },
                  itemBuilder: (context, i) {
                    final index = (player.index ?? -1) + 1 + i;
                    final song = queue[index];
                    return _QueueTile(
                      key: ValueKey(song.key),
                      index: index,
                      song: song,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({super.key, required this.index, required this.song});

  final int index;
  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerController>();
    return Dismissible(
      key: ValueKey('dismiss-${song.key}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withValues(alpha: 0.7),
        child: const Icon(Icons.delete_outline_rounded),
      ),
      onDismissed: (_) => player.removeAt(index),
      child: ListTile(
        onTap: () => player.jumpTo(index),
        leading: Artwork(url: song.artworkUrl, size: 44, seed: song.key),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: player.shuffle ? null : const Icon(Icons.drag_handle_rounded),
      ),
    );
  }
}

// ----------------------------------------------------------------- lyrics

void showLyricsSheet(BuildContext context) =>
    _sheet(context, const _LyricsSheet(), heightFactor: 0.92);

class _LyricsSheet extends StatefulWidget {
  const _LyricsSheet();

  @override
  State<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<_LyricsSheet> {
  Song? _song;
  Future<Lyrics>? _lyrics;
  final _scroll = ScrollController();
  int _lastIndex = -1;
  static const _lineHeight = 56.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow(int index) {
    if (index == _lastIndex || !_scroll.hasClients) return;
    _lastIndex = index;
    final target =
        (index * _lineHeight -
                _scroll.position.viewportDimension / 2 +
                _lineHeight)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();
    if (song != _song) {
      _song = song;
      _lastIndex = -1;
      _lyrics = context.read<LyricsService>().fetch(song);
    }
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(song.title, style: theme.textTheme.titleLarge),
        Text(
          song.artist,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<Lyrics>(
            future: _lyrics,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final lyrics = snap.data;
              if (snap.hasError || lyrics == null || lyrics.isEmpty) {
                return const _Empty(
                  icon: Icons.lyrics_outlined,
                  text:
                      'No lyrics found for this song yet.\n'
                      'Lyrics need an internet connection.',
                );
              }
              if (!lyrics.isSynced) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    lyrics.plain!,
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.7),
                  ),
                );
              }
              return StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, pos) {
                  final current = lyrics.indexAt(pos.data ?? player.position);
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _follow(current),
                  );
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 120,
                    ),
                    itemCount: lyrics.synced.length,
                    itemExtent: _lineHeight,
                    itemBuilder: (context, i) {
                      final line = lyrics.synced[i];
                      final active = i == current;
                      return InkWell(
                        onTap: () => player.seek(line.time),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            maxLines: 2,
                            style: theme.textTheme.titleLarge!.copyWith(
                              fontSize: active ? 22 : 19,
                              fontWeight: active
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: active
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: i < current ? 0.45 : 0.3,
                                    ),
                            ),
                            child: Text(line.text.isEmpty ? '♪' : line.text),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Lyrics from LRCLIB',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ sleep timer

void showSleepTimerSheet(BuildContext context) {
  final player = context.read<PlayerController>();
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      void set(Duration? d, {bool endOfSong = false}) {
        player.setSleepTimer(d, endOfSong: endOfSong);
        Navigator.pop(sheet);
      }

      final remaining = player.sleepRemaining;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sleep timer', style: Theme.of(sheet).textTheme.titleLarge),
            if (remaining != null) Text('${remaining.inMinutes + 1} min left'),
            if (player.sleepAtEndOfSong) const Text('Stops after this song'),
            const SizedBox(height: 8),
            for (final m in [5, 15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$m minutes'),
                onTap: () => set(Duration(minutes: m)),
              ),
            ListTile(
              leading: const Icon(Icons.music_off_outlined),
              title: const Text('End of this song'),
              onTap: () => set(null, endOfSong: true),
            ),
            if (player.sleepTimerActive)
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Turn off timer'),
                onTap: () => set(null),
              ),
          ],
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ speed

void showSpeedSheet(BuildContext context) {
  final player = context.read<PlayerController>();
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Playback speed', style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
                ChoiceChip(
                  label: Text('${s}x'),
                  selected: player.speed == s,
                  onSelected: (_) {
                    player.setSpeed(s);
                    Navigator.pop(sheet);
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

// -------------------------------------------------------------- equalizer

void showEqualizerSheet(BuildContext context) =>
    _sheet(context, const _EqualizerSheet(), heightFactor: 0.7);

class _EqualizerSheet extends StatefulWidget {
  const _EqualizerSheet();

  @override
  State<_EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<_EqualizerSheet> {
  late Future<EqualizerInfo?> _info;
  List<double> _gains = [];

  static const presets = <String, List<double>>{
    'Flat': [0, 0, 0, 0, 0],
    'Bass boost': [6, 4, 0, 0, 1],
    'Vocal (Telugu melody)': [-1, 1, 4, 3, 0],
    'Mass beats': [5, 3, -1, 2, 4],
    'Carnatic': [0, 2, 3, 2, 3],
    'Treble': [-2, -1, 0, 3, 5],
  };

  @override
  void initState() {
    super.initState();
    final saved = context.read<SettingsController>().equalizerGains;
    _info = context.read<PlayerController>().engine.equalizer().then((info) {
      if (info != null) {
        _gains = saved.length == info.bands.length
            ? saved
            : info.bands.map((b) => b.gain).toList();
      }
      return info;
    });
  }

  Future<void> _setGain(int band, double gain) async {
    setState(() => _gains[band] = gain);
    final engine = context.read<PlayerController>().engine;
    final settings = context.read<SettingsController>();
    await engine.setBandGain(band, gain);
    await settings.setEqualizerGains(List.of(_gains));
  }

  Future<void> _applyPreset(List<double> preset, EqualizerInfo info) async {
    for (var i = 0; i < info.bands.length; i++) {
      final p = preset[(i * preset.length / info.bands.length).floor()];
      await _setGain(i, p.clamp(info.minDb, info.maxDb));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final engine = context.read<PlayerController>().engine;
    final theme = Theme.of(context);
    return FutureBuilder<EqualizerInfo?>(
      future: _info,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final info = snap.data;
        if (info == null) {
          return const _Empty(
            icon: Icons.equalizer_rounded,
            text:
                'The equalizer is available on Android while a song is '
                'loaded.\nOn iPhone, use Settings › Music › EQ.',
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            SwitchListTile(
              title: Text('Equalizer', style: theme.textTheme.titleLarge),
              value: settings.equalizerEnabled,
              onChanged: (v) {
                settings.setEqualizerEnabled(v);
                engine.setEqualizerEnabled(v);
              },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final e in presets.entries)
                  ActionChip(
                    label: Text(e.key),
                    onPressed: settings.equalizerEnabled
                        ? () => _applyPreset(e.value, info)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final band in info.bands)
                    Column(
                      children: [
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              min: info.minDb,
                              max: info.maxDb,
                              value: _gains[band.index].clamp(
                                info.minDb,
                                info.maxDb,
                              ),
                              onChanged: settings.equalizerEnabled
                                  ? (v) => _setGain(band.index, v)
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          band.centerHz >= 1000
                              ? '${(band.centerHz / 1000).toStringAsFixed(1)}k'
                              : band.centerHz.toStringAsFixed(0),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Loudness boost • ${settings.loudnessBoost.round()} dB',
              style: theme.textTheme.titleMedium,
            ),
            Slider(
              min: 0,
              max: 10,
              divisions: 10,
              value: settings.loudnessBoost,
              onChanged: (v) {
                settings.setLoudnessBoost(v);
                engine.setLoudnessBoost(v);
              },
            ),
          ],
        );
      },
    );
  }
}
