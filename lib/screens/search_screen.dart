import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../player/player_controller.dart';
import '../widgets/track_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  String? _instrument;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<PlayerController>().library;
    final instruments = {for (final t in library) t.instrumentLabel}.toList()
      ..sort();
    final results = library
        .where((t) => t.matches(_query))
        .where((t) => _instrument == null || t.instrumentLabel == _instrument)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: SearchBar(
            controller: _controller,
            hintText: 'Search songs, ragas, instruments',
            leading: const Icon(Icons.search),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final i in instruments)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(i),
                    selected: _instrument == i,
                    onSelected: (on) =>
                        setState(() => _instrument = on ? i : null),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? const _EmptyResults()
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) =>
                      TrackTile(track: results[i], queue: results),
                ),
        ),
      ],
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('No songs match your search'),
        ],
      ),
    );
  }
}
