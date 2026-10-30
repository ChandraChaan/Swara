import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/languages.dart';
import '../../data/catalog_repository.dart';
import '../../data/library_store.dart';
import '../widgets/song_actions.dart';
import '../../services/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final store = context.watch<LibraryStore>();
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          header('Languages'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your home feed is built around these languages. The first '
              'one is your main language.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in languages)
                  FilterChip(
                    label: Text('${l.name} • ${l.nativeName}'),
                    selected: settings.languageCodes.contains(l.code),
                    onSelected: (_) => settings.toggleLanguage(l.code),
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.star_rounded),
            title: const Text('Main language'),
            trailing: DropdownButton<String>(
              value: settings.languageCodes.first,
              underline: const SizedBox.shrink(),
              items: [
                for (final l in languages)
                  DropdownMenuItem(value: l.code, child: Text(l.name)),
              ],
              onChanged: (c) {
                if (c != null) settings.setPrimaryLanguage(c);
              },
            ),
          ),
          header('Playback & data'),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_off_rounded),
            title: const Text('Offline mode'),
            subtitle: const Text(
              'Only play downloaded and device songs. Saves mobile data.',
            ),
            value: settings.offlineMode,
            onChanged: settings.setOfflineMode,
          ),
          ListTile(
            leading: const Icon(Icons.storage_rounded),
            title: const Text('Downloads'),
            subtitle: Text(
              '${store.downloads.length} songs • '
              '${formatBytes(store.downloadedBytes)}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear image & search cache'),
            onTap: () async {
              context.read<CatalogRepository>().clearCache();
              await DefaultCacheManager().emptyCache();
              if (context.mounted) showMessage(context, 'Cache cleared');
            },
          ),
          header('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            trailing: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Accent colour'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 10,
                children: [
                  for (var i = 0; i < SettingsController.accents.length; i++)
                    GestureDetector(
                      onTap: () => settings.setAccent(i),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: SettingsController.accents[i],
                        child: settings.accent == SettingsController.accents[i]
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          header('Privacy'),
          ListTile(
            leading: const Icon(Icons.history_toggle_off_rounded),
            title: const Text('Clear listening history'),
            onTap: () {
              store.clearHistory();
              showMessage(context, 'History cleared');
            },
          ),
          ListTile(
            leading: const Icon(Icons.search_off_rounded),
            title: const Text('Clear recent searches'),
            onTap: () {
              store.clearRecentSearches();
              showMessage(context, 'Recent searches cleared');
            },
          ),
          header('About'),
          const AboutListTile(
            icon: Icon(Icons.info_outline_rounded),
            applicationName: 'Swara',
            applicationVersion: '2.0.0',
            applicationLegalese:
                'Music streams from Audius and the Internet Archive. Lyrics '
                'from LRCLIB. All songs belong to their respective artists '
                'and labels.',
            child: Text('About Swara'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
