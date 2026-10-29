/// Where a song comes from. Online sources need a network connection unless
/// the song has been downloaded; [asset] and [device] always play offline.
enum SongSource { asset, device, audius, archive }

extension SongSourceLabel on SongSource {
  String get label {
    switch (this) {
      case SongSource.asset:
        return 'Built-in';
      case SongSource.device:
        return 'On this device';
      case SongSource.audius:
        return 'Audius';
      case SongSource.archive:
        return 'Internet Archive';
    }
  }

  bool get isOnline => this == SongSource.audius || this == SongSource.archive;
}

class Song {
  const Song({
    required this.id,
    required this.source,
    required this.title,
    required this.uri,
    this.artist = 'Unknown artist',
    this.album = '',
    this.artworkUrl,
    this.duration,
    this.language,
    this.genre,
  });

  /// Identifier that is unique within [source].
  final String id;
  final SongSource source;
  final String title;
  final String artist;
  final String album;

  /// Stream URL for online songs, `asset:///…` for bundled songs and a file
  /// path for device songs.
  final String uri;

  /// Remote artwork URL, `asset:///…` or a local file path.
  final String? artworkUrl;
  final Duration? duration;
  final String? language;
  final String? genre;

  /// Globally unique key used for likes, downloads, history and playlists.
  String get key => '${source.name}:$id';

  String get subtitle => album.isEmpty ? artist : '$artist • $album';

  Song copyWith({String? uri, String? artworkUrl, Duration? duration}) {
    return Song(
      id: id,
      source: source,
      title: title,
      uri: uri ?? this.uri,
      artist: artist,
      album: album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      duration: duration ?? this.duration,
      language: language,
      genre: genre,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.name,
    'title': title,
    'artist': artist,
    'album': album,
    'uri': uri,
    if (artworkUrl != null) 'artworkUrl': artworkUrl,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
    if (language != null) 'language': language,
    if (genre != null) 'genre': genre,
  };

  factory Song.fromJson(Map<dynamic, dynamic> json) {
    final durationMs = json['durationMs'] as int?;
    return Song(
      id: json['id'] as String,
      source: SongSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => SongSource.device,
      ),
      title: json['title'] as String,
      artist: json['artist'] as String? ?? 'Unknown artist',
      album: json['album'] as String? ?? '',
      uri: json['uri'] as String,
      artworkUrl: json['artworkUrl'] as String?,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      language: json['language'] as String?,
      genre: json['genre'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is Song && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Song($key, $title)';
}
