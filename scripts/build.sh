#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT="$PWD"
DIST="$ROOT/dist"
APP="DDEVManager.app"

echo "==> Generating Xcode project"
/opt/homebrew/bin/xcodegen generate

echo "==> Running unit tests"
swift test

echo "==> Building Release"
rm -rf "$ROOT/build" "$DIST"
xcodebuild -project DDEVManager.xcodeproj -scheme DDEVManager \
  -configuration Release -derivedDataPath "$ROOT/build" build

mkdir -p "$DIST"
cp -R "$ROOT/build/Build/Products/Release/$APP" "$DIST/$APP"

echo "==> Ad-hoc signing (local use, not notarized)"
codesign --force --deep --sign - "$DIST/$APP"
codesign --verify --verbose=2 "$DIST/$APP"

echo "==> Done: $DIST/$APP"
echo "    Install with: cp -R \"$DIST/$APP\" /Applications/"
