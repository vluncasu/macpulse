#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.build/DerivedData}"
DIST="${DIST:-$ROOT/dist}"
CONFIGURATION="${CONFIGURATION:-Release}"
UNIVERSAL="${UNIVERSAL:-1}"
ARCH_ARGS=()

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: building a macOS app requires macOS and Xcode." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: xcodebuild was not found. Install Xcode and open it once." >&2
  exit 1
fi

if [[ "$UNIVERSAL" == "1" ]]; then
  ARCH_ARGS+=("ARCHS=arm64 x86_64" "ONLY_ACTIVE_ARCH=NO")
fi

rm -rf "$DERIVED_DATA" "$DIST"
mkdir -p "$DIST"

BUILD_LOG="$DIST/xcodebuild.log"
set +e
xcodebuild \
  -project "$ROOT/MacPulse.xcodeproj" \
  -scheme MacPulse \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  "${ARCH_ARGS[@]}" \
  build | tee "$BUILD_LOG"
status=${PIPESTATUS[0]}
set -e
[[ "$status" -eq 0 ]] || exit "$status"

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/MacPulse.app"
[[ -d "$APP" ]] || { echo "Build did not produce $APP" >&2; exit 1; }

# Xcode signs the app and embedded WidgetKit extension ad hoc (identity "-").
# This is sufficient for local execution but is not a public distribution signature.
codesign --verify --deep --strict --verbose=2 "$APP"

ditto "$APP" "$DIST/MacPulse.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DIST/MacPulse.app/Contents/Info.plist")
ARCHIVE="$DIST/MacPulse-$VERSION-local.zip"
ditto -c -k --sequesterRsrc --keepParent "$DIST/MacPulse.app" "$ARCHIVE"

(
  cd "$DIST"
  shasum -a 256 "$(basename "$ARCHIVE")" > SHA256SUMS.txt
)

printf '\nCreated without Apple Team ID:\n  %s\n  %s\n  %s\n' \
  "$DIST/MacPulse.app" "$ARCHIVE" "$DIST/SHA256SUMS.txt"
