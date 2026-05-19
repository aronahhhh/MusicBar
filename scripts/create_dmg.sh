#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"
APP_DIR="${2:-$ROOT_DIR/dist/MusicBar.app}"
DIST_DIR="$ROOT_DIR/dist"

if [[ -z "$VERSION" ]]; then
  echo "Usage: scripts/create_dmg.sh <version> [app-path]" >&2
  exit 64
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  exit 66
fi

mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/MusicBar-v$VERSION.dmg"
TMP_BASE="${TMPDIR:-/private/tmp}"
if [[ ! -d "$TMP_BASE" ]]; then
  TMP_BASE="/private/tmp"
fi
STAGING_DIR="$(mktemp -d "$TMP_BASE/musicbar-dmg.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$APP_DIR" "$STAGING_DIR/MusicBar.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "MusicBar" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
