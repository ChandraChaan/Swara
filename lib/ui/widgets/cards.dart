import 'package:flutter/material.dart';

import '../../models/collection.dart';
import '../../models/song.dart';
import 'artwork.dart';

const _cardWidth = 148.0;

class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.song,
    required this.onTap,
    this.onLongPress,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return _Card(
      artwork: Artwork(url: song.artworkUrl, size: _cardWidth, seed: song.key),
      title: song.title,
      subtitle: song.artist,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
  });

  final SongCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Card(
      artwork: Artwork(
        url: collection.artworkUrl,
        size: _cardWidth,
        seed: collection.key,
        icon: Icons.album_rounded,
      ),
      title: collection.title,
      subtitle: collection.subtitle,
      onTap: onTap,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });

  final Widget artwork;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _cardWidth,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            artwork,
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A titled, horizontally scrolling row of cards.
class Carousel extends StatelessWidget {
  const Carousel({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onSeeAll != null)
                TextButton(onPressed: onSeeAll, child: const Text('See all')),
            ],
          ),
        ),
        SizedBox(
          height: _cardWidth + 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

/// Grey placeholder row shown while a carousel loads.
class CarouselSkeleton extends StatelessWidget {
  const CarouselSkeleton({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Carousel(
      title: title,
      itemCount: 4,
      itemBuilder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _cardWidth,
            height: _cardWidth,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          Container(width: 110, height: 10, color: color),
          const SizedBox(height: 6),
          Container(width: 70, height: 8, color: color),
        ],
      ),
    );
  }
}
