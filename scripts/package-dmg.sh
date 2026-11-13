#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.0.0}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || {
  echo "Usage: $0 [version, e.g. 1.0.0]" >&2
  exit 1
}
APP="$ROOT/dist/Battery Time.app"
[[ -d "$APP" ]] || { echo "Run scripts/build-release.sh first." >&2; exit 1; }
codesign --verify --strict --verbose=2 "$APP"
ARCHITECTURE="$(lipo -archs "$APP/Contents/MacOS/Battery Time")"
[[ "$ARCHITECTURE" == "arm64" ]] || { echo "Expected an arm64-only app." >&2; exit 1; }
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ "$APP_VERSION" == "$VERSION" ]] || {
  echo "Requested DMG version $VERSION differs from app version $APP_VERSION." >&2
  exit 1
}

mkdir -p "$ROOT/build" "$ROOT/dist"
STAGING="$(mktemp -d "$ROOT/build/dmg.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Battery Time.app"
ln -s /Applications "$STAGING/Applications"
DMG="$ROOT/dist/Battery-Time-$VERSION-arm64.dmg"
hdiutil create -volname "Battery Time" -srcfolder "$STAGING" \
  -format UDZO -imagekey zlib-level=9 -ov "$DMG"
hdiutil verify "$DMG"
cd "$ROOT/dist"
shasum -a 256 "$(basename "$DMG")" > SHA256SUMS.txt
echo "Packaged $DMG"
cat SHA256SUMS.txt
