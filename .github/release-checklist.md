# Release checklist

- [ ] Update screenshots or demo GIF in `README.md`.
- [ ] Run `scripts/build_app.sh`.
- [ ] Run `codesign --verify --verbose dist/MusicBar.app`.
- [ ] Run `plutil -lint dist/MusicBar.app/Contents/Info.plist`.
- [ ] Zip `dist/MusicBar.app`.
- [ ] Create a GitHub Release.
- [ ] Include install notes, fixed issues, and known limitations.
- [ ] Test first launch permissions on a clean macOS user account if possible.
