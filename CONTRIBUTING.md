# Contributing

Thanks for helping improve MusicBar.

## Good issue reports

For bugs, include:

- macOS version
- MusicBar version or commit
- Apple Music playback state
- steps to reproduce
- screenshots or screen recordings if the issue is visual

For lyrics matching issues, include:

- song title
- artist
- album
- whether lyrics are missing, wrong, or out of sync

## Development

Build the app bundle:

```bash
scripts/build_app.sh
```

Verify the built app:

```bash
codesign --verify --verbose dist/MusicBar.app
plutil -lint dist/MusicBar.app/Contents/Info.plist
```

## Scope

The free version currently focuses on Apple Music. Requests for more players are welcome, but new integrations should keep the core menu bar experience lightweight.
