# Changelog

## Unreleased

## 0.1.3

### Changed

- Restored the full local development build with lyrics window controls, auto lyrics window, opacity, pinning, launch at login, and lyric-line seeking.
- Added `MUSICBAR_EDITION=preview` build support so GitHub Preview packages can be generated without removing full-version code from local development.

## 0.1.2

### Changed

- Physically removed Pro lyrics-window controls from the GitHub Preview build.
- Preview builds now contain only the basic lyrics window and playback controls.

### Changed

- Added a preview edition feature gate for the public GitHub build.
- GitHub Preview keeps the core Apple Music menu bar, basic lyrics, and playback control experience.
- Set the default GitHub homepage to `https://github.com/aronahhhh/MusicBar`.

### Removed

- Hid Pro-style controls from the public preview build: auto lyrics window, launch at login, lyrics window pinning, opacity controls, and lyric-line seeking.

## 0.1.0

### Added

- Transparent menu bar now-playing display.
- Hover playback controls.
- Resizable synced lyrics window.
- Auto lyrics window option.
- Launch at Login option.
- Apple Music playback controls.
- Lyrics matching through LRCLIB with NetEase fallback.

### Changed

- Prepared the project for a public GitHub free release.

### Fixed

- Cleaned up the free release scope around Apple Music support.
