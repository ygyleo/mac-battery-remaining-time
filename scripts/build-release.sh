#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v xcodegen >/dev/null || { echo "Install XcodeGen: brew install xcodegen" >&2; exit 1; }
[[ "$(uname -m)" == "arm64" ]] || { echo "Build on an Apple Silicon Mac." >&2; exit 1; }

# Use only project-local derived data and compiler caches.
mkdir -p build/ModuleCache dist
swift -module-cache-path "$ROOT/build/ModuleCache" scripts/generate-icon.swift
xcodegen generate
xcodebuild \
  -project BatteryTime.xcodeproj \
  -scheme BatteryTime \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$ROOT/build/DerivedData" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="${SIGNING_IDENTITY:--}" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}" \
  build

APP="$ROOT/dist/Battery Time.app"
SOURCE="$ROOT/build/DerivedData/Build/Products/Release/Battery Time.app"
[[ -d "$SOURCE" ]] || { echo "Built app was not found: $SOURCE" >&2; exit 1; }
# ditto replaces matching files; remove only the generated app to avoid stale content.
rm -rf "$APP"
ditto "$SOURCE" "$APP"
codesign --verify --strict --verbose=2 "$APP"
ARCHITECTURE="$(lipo -archs "$APP/Contents/MacOS/Battery Time")"
[[ "$ARCHITECTURE" == "arm64" ]] || { echo "Unexpected architecture: $ARCHITECTURE" >&2; exit 1; }
echo "Built $APP ($ARCHITECTURE)."
if [[ "${SIGNING_IDENTITY:--}" == "-" ]]; then
  echo "This is an ad hoc signed build, not Developer ID signed or notarized."
fi
