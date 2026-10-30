import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../player/player_controller.dart';
import '../theme.dart';
import '../widgets/track_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final library = player.library;
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: textTheme.bodyLarge),
                      ShaderMask(
                        shaderCallback: SwaraTheme.brandGradient.createShader,
                        child: Text(
                          'Swara',
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: library.isEmpty
                      ? null
                      : () {
                          if (!player.shuffle) player.toggleShuffle();
                          player.next();
                        },
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Shuffle'),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _SectionTitle('Featured ragas')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 210,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: library.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  _FeaturedCard(track: library[i], queue: library),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _SectionTitle('All tracks · ${library.length}'),
        ),
        SliverList.builder(
          itemCount: library.length,
          itemBuilder: (context, i) =>
              TrackTile(track: library[i], queue: library),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.track, required this.queue});

  final Track track;
  final List<Track> queue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            context.read<PlayerController>().playTrack(track, queue: queue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(track: track, size: 150, radius: 16),
            const SizedBox(height: 8),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${track.instrumentLabel} · ${track.tala}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
