#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$ROOT_DIR/dist/MusicBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
MODULE_CACHE_DIR="/private/tmp/musicbar-module-cache"
TMP_BUILD_DIR="$ROOT_DIR/.build/tmp"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
REQUIRE_SPARKLE="${REQUIRE_SPARKLE:-0}"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE_DIR" "$TMP_BUILD_DIR"
export TMPDIR="$TMP_BUILD_DIR"
swiftc "$ROOT_DIR/scripts/make_icon.swift" \
  -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -o "$BUILD_DIR/make_icon"
"$BUILD_DIR/make_icon"
if swift build \
  --package-path "$ROOT_DIR" \
  --scratch-path "$ROOT_DIR/.build" \
  -c release \
  --product MusicBar; then
  USE_SWIFTPM_BUILD=1
else
  if [[ "$REQUIRE_SPARKLE" == "1" ]]; then
    echo "SwiftPM build failed and REQUIRE_SPARKLE=1 is set; refusing to build a release without Sparkle." >&2
    exit 1
  fi
  USE_SWIFTPM_BUILD=0
  echo "SwiftPM build failed; falling back to direct swiftc build without embedded Sparkle."
  swiftc "$ROOT_DIR"/Sources/MusicBarApp/*.swift \
    -sdk "$SDK_PATH" \
    -module-cache-path "$MODULE_CACHE_DIR" \
    -O \
    -o "$BUILD_DIR/MusicBar"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$BUILD_DIR/MusicBar" "$MACOS_DIR/MusicBar"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/MusicBar.icns" "$RESOURCES_DIR/MusicBar.icns"
SPARKLE_FRAMEWORK=""
if [[ "$USE_SWIFTPM_BUILD" == "1" ]]; then
  SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d | head -n 1 || true)"
fi
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
  cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/"
elif [[ "$REQUIRE_SPARKLE" == "1" ]]; then
  echo "Sparkle.framework was not found; refusing to build a release without Sparkle." >&2
  exit 1
fi
chmod +x "$MACOS_DIR/MusicBar"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
