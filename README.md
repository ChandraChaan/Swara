# Swara — Telugu-first music player

Swara (స్వర) is a Flutter music app for Indian listeners, built around
Telugu first. It streams online and plays offline, with the features people
expect from Spotify, Gaana and JioSaavn.

## Features

**Listen online**
- Telugu-first home feed: Trending in Telugu, Tollywood hits, film classics,
  Bhakti/devotional, Annamacharya keerthanalu, folk, Carnatic, Ghantasala's
  golden era, Telugu lo-fi.
- Supports Telugu, Hindi, Tamil, Kannada, Malayalam, Punjabi, Bengali, Marathi
  and English. Switch languages with one tap; pick extra languages in
  Settings.
- Personalised rows ("More like <your top artist>") built from your listening
  history.
- Search across every source at once with debouncing, recent searches and
  mood/genre tiles. Results are grouped into songs and albums/playlists.

**Listen offline**
- Download single songs, whole albums or playlists. Files and artwork are
  saved in private app storage. Downloads show progress and can be cancelled
  or retried.
- Import MP3s already on your phone (for example a Telugu collection). Their
  tags and cover art are read automatically.
- Four Telugu songs are built in, so the app plays something even on first
  launch with no internet.
- Goes offline automatically when the connection drops, or turn on Offline
  mode to save data. Songs you can't play offline are dimmed and skipped
  cleanly.
- Search works offline too: it covers downloads, device songs, liked songs
  and history.

**The player**
- Background playback with notification, lock screen, headset, Bluetooth and
  car controls (via `audio_service`). Pauses on calls and when headphones are
  unplugged.
- Full-screen player whose colours follow the album art. Swipe the artwork to
  change songs, swipe down to close.
- Time-synced lyrics from LRCLIB. They scroll with the song, and tapping a line
  jumps to it.
- Queue: play next, add to queue, drag to reorder, swipe to remove.
- Shuffle, repeat all/one, and "previous" restarts the song after 3 seconds,
  like the big apps.
- Sleep timer (minutes or end of song) with a gentle fade-out.
- Playback speed from 0.5× to 2×.
- 5-band equalizer with presets (Bass boost, Vocal/Telugu melody, Mass beats,
  Carnatic…) and loudness boost. Android only.
- Gapless queue playback. Your last queue and position come back when you
  reopen the app.

**Library**
- Liked Songs, Downloads (with storage used), On this device, Recently played.
- Your own playlists: create, rename, reorder, delete, and add whole albums at
  once.
- Share songs. Dark/light/auto theme with six accent colours.

## Music sources

| Source | What it adds | Why |
| --- | --- | --- |
| [Audius](https://audius.org) | Modern, independent Telugu and Indian tracks and playlists | Open API that allows third-party streaming |
| [Internet Archive](https://archive.org) | Huge library of Telugu devotional, Carnatic, folk and old film albums | Public library with an open API |
| Your phone | Any MP3/M4A you import | Your own files |
| Built-in | 4 Telugu songs in `assets/audio` | Works on first launch |

New releases from big labels (T-Series, Aditya Music, Lahari, Sony…) need a
licensed catalog, the same deal Spotify and Gaana sign. The app is built for
that. Implement `MusicSource` (`lib/data/sources/music_source.dart`) for a
licensed API and register it in `CatalogRepository`. Everything else
(downloads, queue, lyrics, offline) works with it unchanged.

## Project layout

```
lib/
  core/        theme, formatting, languages and home-feed curation
  models/      Song, SongCollection, UserPlaylist, Lyrics
  data/        catalog sources, LibraryStore (Hive), lyrics
  services/    audio engine + audio_service handler, PlayerController,
               downloads, connectivity, settings, device import
  ui/          shell (tabs + mini player), screens, widgets
test/          unit + widget tests (fake audio engine, mocked HTTP)
```

## Run it

```bash
flutter pub get
flutter run            # Android or iOS device/emulator
flutter test           # 45 tests
flutter analyze
```

Requires Flutter 3.32+ (Dart 3.8+).
