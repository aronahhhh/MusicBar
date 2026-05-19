# Release checklist

- [ ] Update screenshots or demo GIF in `README.md`.
- [ ] Update `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`.
- [ ] Ensure `Info.plist` has the real Sparkle `SUPublicEDKey`.
- [ ] Ensure the GitHub secret `SPARKLE_PRIVATE_KEY` is configured.
- [ ] Ensure GitHub Pages publishes from `main` / `docs`.
- [ ] Run `REQUIRE_SPARKLE=1 scripts/build_app.sh` on a machine with a full Xcode/SwiftPM Sparkle build.
- [ ] Run `codesign --verify --verbose dist/MusicBar.app`.
- [ ] Run `plutil -lint dist/MusicBar.app/Contents/Info.plist`.
- [ ] Run `scripts/create_dmg.sh <version>`.
- [ ] Push a matching tag, for example `git tag v0.2.1 && git push origin v0.2.1`.
- [ ] Confirm the Release workflow creates `MusicBar-v<version>.dmg`.
- [ ] Confirm the workflow commits the updated `docs/appcast.xml`.
- [ ] Confirm the app's manual update check detects the release from an older build.
- [ ] Test first launch permissions on a clean macOS user account if possible.
