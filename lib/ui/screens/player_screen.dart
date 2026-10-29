import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/library_store.dart';
import '../../models/song.dart';
import '../../services/audio_engine.dart';
import '../../services/download_manager.dart';
import '../../services/player_controller.dart';
import '../widgets/artwork.dart';
import '../widgets/artwork_color.dart';
import '../widgets/song_actions.dart';
import 'player_sheets.dart';

void openPlayer(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => const PlayerScreen(),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );
}

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold();
    }

    return ArtworkColorBuilder(
      artworkUrl: song.artworkUrl,
      fallback: Theme.of(context).colorScheme.primary,
      builder: (context, color) => Scaffold(
        backgroundColor: Colors.black,
        body: Theme(
          data: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.dark,
            ),
            sliderTheme: Theme.of(context).sliderTheme.copyWith(
              activeTrackColor: Colors.white,
              thumbColor: Colors.white,
              inactiveTrackColor: Colors.white24,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(color, Colors.black, 0.25)!,
                  Color.lerp(color, Colors.black, 0.75)!,
                  Colors.black,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
            child: SafeArea(
              child: GestureDetector(
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 500) Navigator.pop(context);
                },
                child: _PlayerBody(song: song),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerBody extends StatelessWidget {
  const _PlayerBody({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = (constraints.maxWidth - 48).clamp(
          160.0,
          constraints.maxHeight * 0.44,
        );
        return Column(
          children: [
            _TopBar(song: song),
            const Spacer(),
            GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -300) player.next();
                if (v > 300) player.previous();
              },
              child: AnimatedScale(
                scale: player.playing ? 1 : 0.9,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Hero(
                  tag: 'artwork',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 32,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Artwork(
                        key: ValueKey(song.key),
                        url: song.artworkUrl,
                        size: artSize,
                        radius: 12,
                        seed: song.key,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _TitleRow(song: song),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: _SeekBar(),
            ),
            const _Controls(),
            const SizedBox(height: 8),
            _BottomActions(song: song),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'PLAYING FROM ${song.source.label.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.album.isEmpty ? song.artist : song.album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showSongActions(context, song),
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final liked = context.select<LibraryStore, bool>((s) => s.isLiked(song));
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: liked ? 'Unlike' : 'Like',
          iconSize: 30,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(liked),
              color: liked ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          onPressed: () => context.read<LibraryStore>().toggleLike(song),
        ),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final total = player.duration ?? Duration.zero;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final position = snap.data ?? player.position;
        final max = total.inMilliseconds.toDouble();
        final value = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(
          0.0,
          max <= 0 ? 1.0 : max,
        );
        final shown = Duration(milliseconds: value.round());
        return Column(
          children: [
            Slider(
              min: 0,
              max: max <= 0 ? 1 : max,
              value: max <= 0 ? 0 : value,
              onChanged: max <= 0
                  ? null
                  : (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                player.seek(Duration(milliseconds: v.round()));
                setState(() => _dragValue = null);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(shown),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  Text(
                    max <= 0 ? '--:--' : '-${formatDuration(total - shown)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Shuffle',
            icon: Icon(
              Icons.shuffle_rounded,
              color: player.shuffle ? accent : Colors.white70,
            ),
            onPressed: () => player.setShuffle(!player.shuffle),
          ),
          IconButton(
            tooltip: 'Previous',
            iconSize: 42,
            icon: const Icon(Icons.skip_previous_rounded),
            onPressed: player.previous,
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: player.togglePlay,
                child: Center(
                  child: player.buffering && player.playing
                      ? const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                      : Icon(
                          player.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 44,
                          color: Colors.black,
                          semanticLabel: player.playing ? 'Pause' : 'Play',
                        ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next',
            iconSize: 42,
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: player.next,
          ),
          IconButton(
            tooltip: 'Repeat',
            icon: Icon(
              player.repeat == RepeatSetting.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: player.repeat == RepeatSetting.off
                  ? Colors.white70
                  : accent,
            ),
            onPressed: player.cycleRepeat,
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final accent = Theme.of(context).colorScheme.primary;
    final downloaded = context.select<LibraryStore, bool>(
      (s) => s.isDownloaded(song),
    );
    final task = context.watch<DownloadManager>().task(song);

    Widget downloadIcon;
    if (downloaded || !song.source.isOnline) {
      downloadIcon = Icon(Icons.download_done_rounded, color: accent);
    } else if (task != null && task.status != DownloadStatus.failed) {
      downloadIcon = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: task.progress,
          color: Colors.white,
        ),
      );
    } else {
      downloadIcon = const Icon(Icons.download_rounded);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: 'Lyrics',
            icon: const Icon(Icons.lyrics_outlined),
            onPressed: () => showLyricsSheet(context),
          ),
          IconButton(
            tooltip: downloaded ? 'Downloaded' : 'Download',
            icon: downloadIcon,
            onPressed: () {
              if (!song.source.isOnline) {
                showMessage(context, 'This song is already on your device');
              } else if (downloaded) {
                showMessage(context, 'Available offline');
              } else if (task == null || task.status == DownloadStatus.failed) {
                final downloads = context.read<DownloadManager>();
                if (task != null) {
                  downloads.retry(song);
                } else {
                  downloads.enqueue([song]);
                }
                showMessage(context, 'Downloading for offline listening');
              }
            },
          ),
          IconButton(
            tooltip: 'Sleep timer',
            icon: Icon(
              Icons.bedtime_outlined,
              color: player.sleepTimerActive ? accent : null,
            ),
            onPressed: () => showSleepTimerSheet(context),
          ),
          TextButton(
            onPressed: () => showSpeedSheet(context),
            child: Text(
              '${player.speed.toStringAsFixed(player.speed % 1 == 0 ? 0 : 2).replaceAll(RegExp(r'0$'), '')}x',
              style: TextStyle(
                color: player.speed == 1 ? Colors.white : accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Equalizer',
            icon: const Icon(Icons.equalizer_rounded),
            onPressed: () => showEqualizerSheet(context),
          ),
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () => showQueueSheet(context),
          ),
        ],
      ),
    );
  }
}
