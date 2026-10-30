import 'song.dart';

/// An album or playlist coming from an online source. Its tracks are loaded
/// lazily when the user opens it.
class SongCollection {
  const SongCollection({
    required this.id,
    required this.source,
    required this.title,
    this.subtitle = '',
    this.artworkUrl,
  });

  final String id;
  final SongSource source;
  final String title;
  final String subtitle;
  final String? artworkUrl;

  String get key => '${source.name}:$id';

  @override
  bool operator ==(Object other) => other is SongCollection && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A playlist the user created. Songs are stored inline so playlists keep
/// working offline and even if the original source disappears.
class UserPlaylist {
  UserPlaylist({
    required this.id,
    required this.name,
    List<Song>? songs,
    DateTime? createdAt,
  }) : songs = songs ?? [],
       createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  final List<Song> songs;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'songs': songs.map((s) => s.toJson()).toList(),
  };

  factory UserPlaylist.fromJson(Map<dynamic, dynamic> json) => UserPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      json['createdAt'] as int? ?? 0,
    ),
    songs: (json['songs'] as List? ?? [])
        .map((s) => Song.fromJson(s as Map))
        .toList(),
  );
}
