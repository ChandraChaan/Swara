import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

const _repoUrl = 'https://github.com/ChandraChaan/Swara';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 96,
              height: 96,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Swara',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Center(
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            // Only the version name: split-per-ABI APKs offset the build number.
            builder: (context, snap) => Text(
              snap.hasData ? 'Version ${snap.data!.version}' : '',
              style: textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Swara (స్వర, "musical note") is a simple, ad-free music player built with '
          'Flutter. It ships with ten original demo tracks, each one an improvisation '
          'on a different raga, played over a tanpura drone and tabla rhythm.',
          style: textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const _Section(
          title: 'Features',
          items: [
            (Icons.queue_music, 'Play, pause, seek, next and previous'),
            (Icons.shuffle, 'Shuffle, repeat all and repeat one'),
            (Icons.favorite, 'Favourites that are saved on your device'),
            (Icons.search, 'Search by song, raga or instrument'),
            (Icons.dark_mode, 'A dark theme that is easy on the eyes'),
          ],
        ),
        const _Section(
          title: 'About the music',
          items: [
            (
              Icons.auto_awesome,
              'Every track is synthesized by tool/generate_tracks.py',
            ),
            (
              Icons.public,
              'The audio and cover art are dedicated to the public domain (CC0)',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Source code on GitHub'),
                subtitle: const Text('ChandraChaan/Swara'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open(_repoUrl),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Report a bug or suggest a feature'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open('$_repoUrl/issues'),
              ),
              ListTile(
                leading: const Icon(Icons.system_update),
                title: const Text('Check for new releases'),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _open('$_repoUrl/releases'),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open-source licences'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Swara',
                  applicationLegalese: '© 2026 ChandraChaan · MIT License',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: ShaderMask(
            shaderCallback: SwaraTheme.brandGradient.createShader,
            child: Text(
              'Made with ♥ and Flutter',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final (icon, text) in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: SwaraTheme.accent),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
