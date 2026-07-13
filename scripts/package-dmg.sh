#!/bin/bash
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/MacPulse.app}"
DIST="${DIST:-$ROOT/dist}"
VOLUME_BASENAME="MacPulse"
SKIP_FINDER_LAYOUT="${SKIP_FINDER_LAYOUT:-0}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: DMG creation requires macOS and hdiutil." >&2
  exit 1
fi

for command in hdiutil ditto; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Error: required command not found: $command" >&2
    exit 1
  }
done

if [[ "$SKIP_FINDER_LAYOUT" != "1" ]]; then
  command -v osascript >/dev/null 2>&1 || {
    echo "Error: required command not found: osascript" >&2
    exit 1
  }
fi

[[ -d "$APP" ]] || {
  echo "Error: application bundle not found: $APP" >&2
  echo "Build the application first with scripts/build-local.sh." >&2
  exit 1
}

INFO_PLIST="$APP/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || {
  echo "Error: invalid application bundle; Info.plist is missing." >&2
  exit 1
}

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")
OUTPUT_DMG="$DIST/MacPulse-$VERSION.dmg"
RW_DMG="$DIST/.MacPulse-$VERSION-rw.dmg"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/macpulse-dmg.XXXXXX")"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" ]] && mount | grep -Fq "$MOUNT_POINT"; then
    hdiutil detach "$MOUNT_POINT" -quiet || hdiutil detach "$MOUNT_POINT" -force -quiet || true
  fi
  rm -rf "$STAGE" "$RW_DMG"
}
trap cleanup EXIT

mkdir -p "$DIST" "$STAGE/source"
ditto "$APP" "$STAGE/source/MacPulse.app"
ln -s /Applications "$STAGE/source/Applications"

# Create a writable image first so Finder metadata can be configured.
hdiutil create \
  -volname "$VOLUME_BASENAME" \
  -srcfolder "$STAGE/source" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$RW_DMG" >/dev/null

ATTACH_OUTPUT=$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen)
DEVICE=$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $1; exit}')
MOUNT_POINT=$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {$1=$2=""; sub(/^  */, ""); print; exit}')

if [[ -z "$DEVICE" || -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Error: failed to mount the writable DMG." >&2
  exit 1
fi

# Configure a conventional drag-to-install Finder window. Failure to set the
# visual layout does not invalidate the DMG; the app and Applications link are
# already present.
if [[ "$SKIP_FINDER_LAYOUT" != "1" ]]; then
osascript <<APPLESCRIPT || true
tell application "Finder"
    tell disk "$VOLUME_BASENAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set pathbar visible of container window to false
        set bounds of container window to {120, 120, 720, 470}
        set arrangement of icon view options of container window to not arranged
        set icon size of icon view options of container window to 104
        set text size of icon view options of container window to 13
        set position of item "MacPulse.app" of container window to {165, 165}
        set position of item "Applications" of container window to {435, 165}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT
fi

sync
hdiutil detach "$DEVICE" -quiet
MOUNT_POINT=""

rm -f "$OUTPUT_DMG"
hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_DMG" >/dev/null

hdiutil verify "$OUTPUT_DMG" >/dev/null

# Write portable checksums containing asset basenames, never developer-machine
# absolute paths. Keep the consolidated checksum file deterministic and avoid
# duplicate DMG entries when packaging is repeated.
(
  cd "$DIST"
  DMG_NAME="$(basename "$OUTPUT_DMG")"
  DMG_CHECKSUM="$DMG_NAME.sha256"
  CHECKSUMS="SHA256SUMS.txt"
  CHECKSUMS_TMP="$(mktemp "${TMPDIR:-/tmp}/macpulse-checksums.XXXXXX")"

  shasum -a 256 "$DMG_NAME" > "$DMG_CHECKSUM"
  if [[ -f "$CHECKSUMS" ]]; then
    awk -v name="$DMG_NAME" '$2 != name' "$CHECKSUMS" > "$CHECKSUMS_TMP"
  fi
  shasum -a 256 "$DMG_NAME" >> "$CHECKSUMS_TMP"
  LC_ALL=C sort -k2,2 "$CHECKSUMS_TMP" > "$CHECKSUMS"
  rm -f "$CHECKSUMS_TMP"
)

printf 'Created DMG:\n  %s\n  %s\n' "$OUTPUT_DMG" "$OUTPUT_DMG.sha256"
printf '\nThe mounted image contains MacPulse.app and an Applications shortcut.\n'
printf 'Install by dragging MacPulse.app onto Applications.\n'
