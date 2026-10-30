/// Indian languages the app curates content for. Telugu is first and is the
/// default, everything else can be switched on in Settings.
class MusicLanguage {
  const MusicLanguage(this.code, this.name, this.nativeName, this.keywords);

  final String code;
  final String name;
  final String nativeName;

  /// Search keywords that surface this language on the online sources.
  final List<String> keywords;
}

const languages = <MusicLanguage>[
  MusicLanguage('te', 'Telugu', 'తెలుగు', ['telugu', 'tollywood']),
  MusicLanguage('hi', 'Hindi', 'हिन्दी', ['hindi', 'bollywood']),
  MusicLanguage('ta', 'Tamil', 'தமிழ்', ['tamil', 'kollywood']),
  MusicLanguage('kn', 'Kannada', 'ಕನ್ನಡ', ['kannada', 'sandalwood']),
  MusicLanguage('ml', 'Malayalam', 'മലയാളം', ['malayalam', 'mollywood']),
  MusicLanguage('pa', 'Punjabi', 'ਪੰਜਾਬੀ', ['punjabi', 'bhangra']),
  MusicLanguage('bn', 'Bengali', 'বাংলা', ['bengali', 'bangla']),
  MusicLanguage('mr', 'Marathi', 'मराठी', ['marathi']),
  MusicLanguage('en', 'English', 'English', ['indian english', 'desi']),
];

MusicLanguage languageByCode(String code) =>
    languages.firstWhere((l) => l.code == code, orElse: () => languages.first);

/// A curated row on the home screen. [query] is sent to the online sources,
/// `{lang}` is replaced with the language keyword.
class HomeSectionSpec {
  const HomeSectionSpec(this.title, this.query, {this.albums = false});

  final String title;
  final String query;

  /// Albums come from the Internet Archive, songs from Audius.
  final bool albums;
}

/// Telugu gets the richest home feed, the others share a generic template.
const teluguSections = <HomeSectionSpec>[
  HomeSectionSpec('Trending in Telugu', 'telugu'),
  HomeSectionSpec('Tollywood hits', 'tollywood'),
  HomeSectionSpec('Telugu film classics', 'telugu film songs', albums: true),
  HomeSectionSpec('Bhakti • Devotional', 'telugu devotional', albums: true),
  HomeSectionSpec('Annamacharya keerthanalu', 'annamacharya', albums: true),
  HomeSectionSpec('Telugu folk & janapadam', 'telugu folk'),
  HomeSectionSpec('Carnatic classical', 'carnatic', albums: true),
  HomeSectionSpec('Ghantasala golden era', 'ghantasala', albums: true),
  HomeSectionSpec('Telugu lo-fi & indie', 'telugu lofi'),
];

List<HomeSectionSpec> sectionsFor(MusicLanguage lang) {
  if (lang.code == 'te') return teluguSections;
  final k = lang.keywords.first;
  return [
    HomeSectionSpec('Trending in ${lang.name}', k),
    HomeSectionSpec('${lang.name} hits', lang.keywords.last),
    HomeSectionSpec('${lang.name} film songs', '$k film songs', albums: true),
    HomeSectionSpec('${lang.name} devotional', '$k devotional', albums: true),
    HomeSectionSpec('${lang.name} indie', '$k indie'),
  ];
}

/// Mood and genre tiles shown on the search screen before the user types.
class BrowseTile {
  const BrowseTile(this.label, this.query, this.colors);

  final String label;
  final String query;
  final List<int> colors;
}

const browseTiles = <BrowseTile>[
  BrowseTile('Telugu', 'telugu', [0xFFFF6B35, 0xFFF7931E]),
  BrowseTile('Devotional', 'telugu devotional', [0xFFFFB300, 0xFFFF7043]),
  BrowseTile('Love', 'telugu love songs', [0xFFE91E63, 0xFF9C27B0]),
  BrowseTile('Mass beats', 'telugu mass', [0xFFD32F2F, 0xFF7B1FA2]),
  BrowseTile('Melody', 'telugu melody', [0xFF26A69A, 0xFF2E7D32]),
  BrowseTile('Folk', 'telugu folk', [0xFF8D6E63, 0xFFFF8F00]),
  BrowseTile('Carnatic', 'carnatic', [0xFF5C6BC0, 0xFF26C6DA]),
  BrowseTile('Bollywood', 'bollywood', [0xFFAB47BC, 0xFFEC407A]),
  BrowseTile('Tamil', 'tamil', [0xFF00897B, 0xFF43A047]),
  BrowseTile('Lo-fi', 'indian lofi', [0xFF3949AB, 0xFF8E24AA]),
  BrowseTile('Workout', 'desi workout', [0xFFF4511E, 0xFFFFB300]),
  BrowseTile('Sleep', 'indian flute', [0xFF283593, 0xFF00838F]),
];
