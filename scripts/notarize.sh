#!/bin/bash
set -euo pipefail

APP="${1:-dist/MacPulse.app}"
[[ -d "$APP" ]] || { echo "App not found: $APP" >&2; exit 1; }
DIST="$(cd "$(dirname "$APP")" && pwd)"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
SUBMISSION="$DIST/MacPulse-$VERSION-notary-submission.zip"
FINAL="$DIST/MacPulse-$VERSION.zip"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$SUBMISSION"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$SUBMISSION" --keychain-profile "$NOTARY_PROFILE" --wait
else
  : "${APPLE_ID:?Set NOTARY_PROFILE or APPLE_ID}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD}"
  xcrun notarytool submit "$SUBMISSION" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
fi

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$FINAL"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$FINAL"
rm -f "$SUBMISSION"
(
  cd "$DIST"
  shasum -a 256 "$(basename "$FINAL")" > SHA256SUMS.txt
)

echo "Notarized package: $FINAL"
