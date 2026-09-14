<div align="center">

# Melody.

**A music app for Android that plays streaming and on-device music through one
interface.**

YouTube Music, Gaana and Saavn behind a single search — plus the music already
on your phone, podcasts, and audiobooks.

No ads. No analytics. No account of ours. Optional YouTube sign-in, kept on your phone.

## Download

**[Latest release](https://github.com/devil6venom/melody/releases/latest)** — take
`app-arm64-v8a-release.apk` unless your phone is 32-bit. Android 7.0+.

### Which APK?

| File | For |
|---|---|
| `app-arm64-v8a-release.apk` | Almost every phone from the last several years |
| `app-armeabi-v7a-release.apk` | Older 32-bit devices |
| `app-x86_64-release.apk` | Emulators, x86 tablets |

---
## Features

### Sources

- **YouTube Music** — search, the home feed with its editorial rows, moods and
  genres, playlists, albums, and artist pages with one-tap radio. It talks to
  the same InnerTube API the official client does, not a web wrapper.
- **Gaana** and **Saavn** — trending, charts, playlists and albums, with strong
  Indian-language coverage.
- **On this device** — your own music files, browsable by song, album and
  artist, with the album art embedded in them.
- Results from every source appear in one search.

### Playback

- [mpv](https://mpv.io) as the audio engine, via `mpv_audio_kit`.
- Gapless queue, shuffle and repeat, reorderable queue.
- **SponsorBlock** on YouTube tracks — skips sponsor reads, intros, outros and
  non-music segments. Only a short hash prefix of the video id is sent, never
  the id itself.
- Equalizer, sleep timer, and Chromecast.
- Word-by-word synced lyrics, looked up across six databases at once —
  Apple Music timings where they exist, whole lines where they don't.
- Media notification with a working seekbar, and full background playback.

### Android Auto

Full browse and playback in the car: Downloads, Liked Songs, Recently Played
and Playlists, plus the Music, Podcasts and Audiobooks feeds, radio stations,
and voice search. Downloads lead deliberately — a car is where the network
drops, and downloaded tracks are the only tier that survives it.

### Library

- Liked songs, user playlists, recently played, and offline downloads.
- Import your playlists from Spotify.
- Podcasts and audiobooks alongside music.

### Interface

- Dark, editorial design. The accent colour follows the album art.
- Artwork requested at full resolution throughout.
- Region and interface language for YouTube can be set by hand or detected
  from your connection.

---

## Privacy

Melody has no account of its own and no user identity, and that is deliberate.

- **No Melody account, ever.** There is nothing to register for, and no server
  of ours that knows who you are.
- **YouTube sign-in is optional and local.** You can sign in to YouTube Music
  to get your own recommendations and library. It uses Google's own sign-in
  page in a web view, so your password is never seen by this app. The session
  it produces is encrypted with a key held in the Android Keystore, stays on
  the phone, is never sent to us, and is never included in library sync. Sign
  out and it is deleted. Everything works without it.
- **No analytics of any kind.** There is no telemetry SDK in the app — Firebase
  was removed outright rather than left switchable, so there is nothing to opt
  out of and nothing to take on trust.
- SponsorBlock lookups send a 4-character hash prefix of the video id — enough
  to fetch segments, not enough to identify the track.
- On-device music never leaves the phone. It is read through MediaStore and
  played from the local file.

---

<div align="center">


### Endpoints

Every endpoint the app talks to lives in `env.json`, which is **gitignored** —
this repository carries no base URL of its own. `env.example.json` documents
the shape; the third-party ones (the lyrics databases, SponsorBlock,
InnerTube) are filled in there because they are public, and the
Melody-specific ones are blank. `MUSIXMATCH_SECRET` is blank too: it is that
service's own signing key, read from their web bundle, and this repository
does not republish it. A build without it simply has one fewer lyrics source.

A build without `env.json` still runs. The on-device library and the YouTube
tier need nothing from Melody-api, so they keep working; the catalog screens
render their normal error state. `scripts/release.sh` refuses to build a
release without it.

This is configuration, not secrecy. A compile-time define is baked into the
APK, so anyone with the file can read every URL out of it — and anyone running
the app can watch them go past in a proxy. The point is that a public
repository does not carry a private backend URL, and that a fork or a
self-hoster can repoint the app without editing code.

Requires the Flutter SDK (Dart `^3.11.5`) and the Android SDK. The YouTube
extraction path and the on-device library are native Kotlin under
`android/app/src/main/kotlin/codes/afk/sunoh/`, so a plain `flutter run` on
Android is the only supported way to exercise them.

Before contributing, read [`docs/ENGINEERING.md`](docs/ENGINEERING.md) — it is
short, and it is the bar.

---

## Architecture

Full detail in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); the standards
new code is held to are in [`docs/ENGINEERING.md`](docs/ENGINEERING.md).

| Path | |
|---|---|
| `lib/api/` | source clients — `ytmusic_api`, `melody_api`, `local_media_channel`, `sponsorblock`, `lrclib` |
| `lib/api/lyrics/` | the six lyrics databases, their parsers, and the race between them |
| `lib/audio/` | playback repository, queue, downloads, Android Auto, on-device library |
| `lib/providers/` | Riverpod providers |
| `lib/screens/`, `lib/overlays/`, `lib/player/` | UI |
| `lib/router/` | `go_router` shell routes |
| `android/.../ytmusic/` | Kotlin InnerTube bridge |
| `android/.../localmedia/` | Kotlin MediaStore bridge |
| `android/.../potoken/` | BotGuard PO token minting in a WebView |

State is Riverpod, navigation is `go_router` with a `StatefulShellRoute`, and
persistence is Hive.

YouTube stream URLs are resolved just-in-time, per track, at playback. Some
tracks require a PO token, which is minted on-device in a WebView using
Google's public BotGuard endpoint — the same approach the official web client
uses.

---

## Credits

- [innertubex](https://github.com/MetrolistGroup/innertubex) by MetrolistGroup,
  for the InnerTube client stack. Melody is GPL-3.0 because it links this.
- [Metrolist](https://github.com/mostafaalagamy/Metrolist), whose approach to
  the YouTube Music home feed and PO tokens this follows.
- [SponsorBlock](https://sponsor.ajay.app) and [LRCLIB](https://lrclib.net) for
  their open APIs.
- [BitChord](https://github.com/kushagrasinghx/BitChord), whose multi-source
  lyrics lookup and word-timing parsers this ports.

---

<div align="center">

## Disclaimer & Legal Notice

</div>

Melody is an independent, community-driven third-party audio player and client.
It is **not** affiliated with, endorsed by, or connected to Google LLC, YouTube,
YouTube Music, Gaana, JioSaavn, Spotify, or any of their parent companies. All
trademarks belong to their respective owners.

- **No media hosting.** Melody does not host, upload, or store copyrighted music
  files. It is an interface: it reads audio already on your device, and streams
  from public, public-facing APIs.

- **Fair use and API usage.** This software exists for personal, educational
  and fair-use purposes. You are responsible for ensuring your use fits your
  local copyright law and the terms of service of the platforms you reach
  through it.

- **No guarantees.** Melody has no ads, but it does not promise to keep
  circumventing anything. Upstream platforms change without notice, and any
  given source can stop working at any time.

- **Privacy.** No account of ours, no analytics, and no listening history
  leaving the phone. YouTube sign-in is optional, and its session never leaves
  the device. On-device music never leaves the device at all. See
  [Privacy](#privacy) above.

- **Copyleft.** Melody is free software under the **GPL-3.0** — see
  [`LICENSE`](LICENSE). The licence does not let anyone forbid others from
  selling or redistributing copies, but any distribution must come with the
  corresponding source under the same licence. It covers the code only, and
  grants no rights in any third-party media, artwork, or metadata reached
  through the app.
