#!/usr/bin/env bash
# Builds a distributable DMG for DDEV Manager.
#
# Works without an Apple Developer account (ad-hoc signed — recipients need one
# Gatekeeper step, see the generated INSTALL.txt), and automatically signs +
# notarizes instead when credentials are available:
#
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"   # or auto-detected
#   NOTARY_PROFILE="ddevmanager"   # created once: xcrun notarytool store-credentials
#
# Usage: ./scripts/package.sh [--skip-build]
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT="$PWD"
DIST="$ROOT/dist"
APP_NAME="DDEVManager.app"
APP="$DIST/$APP_NAME"
STAGE="$DIST/dmg"

if [[ "${1:-}" != "--skip-build" ]]; then
  "$ROOT/scripts/build.sh"
fi

[[ -d "$APP" ]] || { echo "error: $APP not found — run ./scripts/build.sh first" >&2; exit 1; }

PLIST="$APP/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
DMG="$DIST/DDEVManager-$VERSION.dmg"
VOLNAME="DDEV Manager $VERSION"

# ---------------------------------------------------------------- code signing
: "${SIGN_IDENTITY:=}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "==> Signing with: $SIGN_IDENTITY"
  # Hardened runtime + secure timestamp are required for notarization.
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
  SIGNED=1
else
  echo "==> No Developer ID identity found — keeping the ad-hoc signature"
  echo "    (recipients will need the Gatekeeper step from INSTALL.txt)"
  SIGNED=0
fi

# ------------------------------------------------------------------ dmg layout
echo "==> Staging DMG contents"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/$APP_NAME"
ln -s /Applications "$STAGE/Applications"

if [[ "$SIGNED" == "1" ]]; then
  GATEKEEPER_NOTE="This build is signed with an Apple Developer ID, so it opens normally."
else
  GATEKEEPER_NOTE="This build is NOT notarized by Apple. macOS will refuse to open it on the
first try (\"damaged\" or \"unidentified developer\"). Clear the download
quarantine flag once, in Terminal:

    xattr -dr com.apple.quarantine /Applications/DDEVManager.app

Alternative without Terminal: right-click the app in /Applications, choose Open,
then confirm — or open System Settings > Privacy & Security and click
\"Open Anyway\" after the first blocked attempt."
fi

cat > "$STAGE/INSTALL.txt" <<EOF
DDEV Manager $VERSION (build $BUILD)
====================================

A macOS menu bar app for managing DDEV projects.

INSTALL
-------
1. Drag DDEVManager.app onto the Applications folder in this window.
2. $(if [[ "$SIGNED" == "1" ]]; then echo "Launch it from Applications."; else echo "See GATEKEEPER below, then launch it from Applications."; fi)
3. A small rounded-square "D" badge appears in the menu bar — click it.
   There is no Dock icon: this is a menu-bar-only app.

REQUIREMENTS
------------
* macOS 14 (Sonoma) or later
* ddev 1.25+            ->  brew install ddev/ddev/ddev
* A container engine ddev can use: Docker Desktop, OrbStack, Rancher Desktop,
  or Colima. The app detects the active one via "docker context".

GATEKEEPER
----------
$GATEKEEPER_NOTE

UNINSTALL
---------
    rm -rf /Applications/DDEVManager.app
    defaults delete de.markus.ddevmanager

More: https://www.markus-meier.consulting
EOF

# --------------------------------------------------------------- build the dmg
echo "==> Building $DMG"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" \
  -fs HFS+ -format UDZO -ov -quiet "$DMG"
rm -rf "$STAGE"

if [[ "$SIGNED" == "1" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi

# ------------------------------------------------------------- notarize (opt.)
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  if [[ "$SIGNED" != "1" ]]; then
    echo "error: notarization needs a Developer ID signature (set SIGN_IDENTITY)" >&2
    exit 1
  fi
  echo "==> Submitting to Apple notary service (profile: $NOTARY_PROFILE)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  echo "==> Stapled"
else
  echo "==> Skipping notarization (set NOTARY_PROFILE to enable)"
fi

SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
SIZE="$(du -h "$DMG" | cut -f1)"

echo
echo "==> Done: $DMG  ($SIZE)"
echo "    sha256: $SHA"
echo "    verify: hdiutil verify \"$DMG\""
if [[ "$SIGNED" != "1" ]]; then
  echo "    note:   ad-hoc signed — recipients must run"
  echo "            xattr -dr com.apple.quarantine /Applications/DDEVManager.app"
fi
