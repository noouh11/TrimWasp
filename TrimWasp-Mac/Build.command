#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

TRIMWASP_STAGE=""
TRIMWASP_BACKUP=""
TRIMWASP_OUTPUT="$PWD/build/TrimWasp.app"
cleanup() {
  if [[ -n "$TRIMWASP_STAGE" && -d "$TRIMWASP_STAGE" ]]; then
    rm -rf -- "$TRIMWASP_STAGE"
  fi
}
failed() {
  local result=$?
  trap - ERR
  printf '\nBuild/signature check failed (exit %s). The app was not launched.\n' "$result" >&2
  if [[ -t 0 ]]; then read -r -p 'Press Return to close...' _ || true; fi
  exit "$result"
}
trap cleanup EXIT
trap failed ERR

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Build.command must be run on your Mac.' >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Install Apple Command Line Tools first: xcode-select --install' >&2
  if [[ -t 0 ]]; then read -r -p 'Press Return to close...' _ || true; fi
  exit 1
fi

if [[ ! -r Version.txt ]]; then
  echo 'Version.txt is missing or unreadable. Put a version such as 1.7.5 in it.' >&2
  exit 1
fi
TRIMWASP_VERSION="$(tr -d '\r' < Version.txt)"
if [[ ! "$TRIMWASP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Version.txt must contain only a version such as 1.7.5 (three numbers separated by dots).' >&2
  exit 1
fi

TRIMWASP_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/TrimWasp-build.XXXXXX")"
TRIMWASP_APP="$TRIMWASP_STAGE/TrimWasp.app"
mkdir -p "$TRIMWASP_APP/Contents/MacOS" "$TRIMWASP_APP/Contents/Resources"
cp -X Resources/AppIcon.icns "$TRIMWASP_APP/Contents/Resources/AppIcon.icns"
cp -X Info.plist "$TRIMWASP_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $TRIMWASP_VERSION" "$TRIMWASP_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $TRIMWASP_VERSION" "$TRIMWASP_APP/Contents/Info.plist"
TRIMWASP_ARCH="$(uname -m)"
printf 'Building TrimWasp %s for %s...\n' "$TRIMWASP_VERSION" "$TRIMWASP_ARCH"
xcrun swiftc -swift-version 5 -O -whole-module-optimization \
  -target "${TRIMWASP_ARCH}-apple-macos13.0" \
  -framework AppKit -framework AVFoundation -framework AVKit -framework UniformTypeIdentifiers \
  Sources/*.swift -o "$TRIMWASP_APP/Contents/MacOS/TrimWasp"

codesign --force --sign - --identifier local.TrimWasp --timestamp=none "$TRIMWASP_APP"
codesign --verify --deep --strict --verbose=2 "$TRIMWASP_APP"

mkdir -p build
if [[ -e "$TRIMWASP_OUTPUT" ]]; then
  TRIMWASP_BACKUP="$PWD/build/TrimWasp-previous-$(date +%Y%m%d-%H%M%S)-$$.app"
  mv "$TRIMWASP_OUTPUT" "$TRIMWASP_BACKUP"
fi
if ! mv "$TRIMWASP_APP" "$TRIMWASP_OUTPUT"; then
  if [[ -n "$TRIMWASP_BACKUP" ]]; then mv "$TRIMWASP_BACKUP" "$TRIMWASP_OUTPUT"; fi
  echo 'Could not install the new build; the previous app was restored.' >&2
  exit 1
fi
if ! codesign --verify --deep --strict --verbose=2 "$TRIMWASP_OUTPUT"; then
  mv "$TRIMWASP_OUTPUT" "$PWD/build/TrimWasp-failed-$$.app"
  if [[ -n "$TRIMWASP_BACKUP" ]]; then mv "$TRIMWASP_BACKUP" "$TRIMWASP_OUTPUT"; fi
  echo 'Final verification failed. The new build was not launched.' >&2
  exit 1
fi
codesign --display --verbose=2 "$TRIMWASP_OUTPUT"
printf '\nLocal signature verified successfully.\nBuilt: %s\n' "$TRIMWASP_OUTPUT"
if [[ -n "$TRIMWASP_BACKUP" ]]; then printf 'Previous app preserved: %s\n' "$TRIMWASP_BACKUP"; fi
printf 'This is locally signed, not Apple-notarized. macOS may still request Open Anyway.\n'
if ! open "$TRIMWASP_OUTPUT"; then
  echo 'The verified build is ready. If macOS blocked launch, use System Settings > Privacy & Security > Open Anyway.' >&2
fi
