# Privacy

MusicBar is designed as a local macOS menu bar utility.

## Local music app access

MusicBar uses AppleScript to read the current playback state from Apple Music. This can include:

- song title
- artist
- album
- playback state
- artwork
- playback position
- duration

macOS may ask you to allow MusicBar to control Music. This permission is required for now-playing display and playback controls.

## Lyrics matching

When lyrics are loaded, MusicBar sends the current song title, artist, album, and duration to online lyric matching services. This is used only to find matching lyrics for the current track.

MusicBar does not upload your music library, playlists, listening history, or local files.

## Analytics

MusicBar does not include analytics, tracking SDKs, accounts, or telemetry.

## Settings

MusicBar stores settings locally with `UserDefaults`, including the GitHub homepage, lyrics window options, launch-at-login preference, trial start date, and local purchase state.

The current trial implementation is local-only. A future paid release may add license activation against a website or reseller service.
