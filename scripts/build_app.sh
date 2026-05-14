#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/MusicBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE_DIR="/private/tmp/musicbar-module-cache"
TMP_BUILD_DIR="$ROOT_DIR/.build/tmp"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SWIFT_EDITION_FLAGS=()

if [[ "${MUSICBAR_EDITION:-full}" == "preview" ]]; then
  SWIFT_EDITION_FLAGS=(-D PREVIEW)
fi

mkdir -p "$BUILD_DIR" "$MODULE_CACHE_DIR" "$TMP_BUILD_DIR"
export TMPDIR="$TMP_BUILD_DIR"
swiftc "$ROOT_DIR/scripts/make_icon.swift" \
  -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -o "$BUILD_DIR/make_icon"
"$BUILD_DIR/make_icon"
swiftc "$ROOT_DIR"/Sources/MusicBarApp/*.swift \
  -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  "${SWIFT_EDITION_FLAGS[@]+"${SWIFT_EDITION_FLAGS[@]}"}" \
  -O \
  -o "$BUILD_DIR/MusicBar"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BUILD_DIR/MusicBar" "$MACOS_DIR/MusicBar"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/MusicBar.icns" "$RESOURCES_DIR/MusicBar.icns"
chmod +x "$MACOS_DIR/MusicBar"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR (${MUSICBAR_EDITION:-full})"
