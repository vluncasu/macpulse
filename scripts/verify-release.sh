#!/bin/bash
set -euo pipefail

APP="${1:-dist/MacPulse.app}"
[[ -d "$APP" ]] || { echo "App not found: $APP" >&2; exit 1; }
WIDGET="$APP/Contents/PlugIns/MacPulseWidget.appex"
[[ -d "$WIDGET" ]] || { echo "Embedded widget missing" >&2; exit 1; }

printf 'Application: %s\n' "$APP"
/usr/bin/file "$APP/Contents/MacOS/MacPulse"
/usr/bin/lipo -info "$APP/Contents/MacOS/MacPulse" || true

codesign --verify --deep --strict --verbose=2 "$APP"
echo "Signature: valid local ad-hoc signature"

echo "App signature:"
codesign -dv --verbose=2 "$APP" 2>&1 | grep -E 'Identifier=|TeamIdentifier=|Signature=' || true

echo "Widget signature:"
codesign -dv --verbose=2 "$WIDGET" 2>&1 | grep -E 'Identifier=|TeamIdentifier=|Signature=' || true

if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q application-groups; then
  echo "Unexpected App Groups entitlement in app" >&2
  exit 1
fi
if codesign -d --entitlements :- "$WIDGET" 2>/dev/null | grep -q application-groups; then
  echo "Unexpected App Groups entitlement in widget" >&2
  exit 1
fi

echo "No Team ID or App Group provisioning is present."
echo "Gatekeeper assessment may reject an ad-hoc build; this is expected locally."
spctl --assess --type execute --verbose=2 "$APP" || true
