#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

find "$ROOT" -name '*.swift' -not -path '*/.build/*' -print0 | while IFS= read -r -d '' file; do
  swiftc -frontend -parse "$file" >/dev/null
 done

for plist in \
  "$ROOT/MacPulse/Info.plist" \
  "$ROOT/MacPulseWidget/Info.plist" \
  "$ROOT/MacPulse/MacPulse.entitlements" \
  "$ROOT/MacPulseWidget/MacPulseWidget.entitlements" \
  "$ROOT/MacPulse/PrivacyInfo.xcprivacy"; do
  plutil -lint "$plist" >/dev/null
 done

find "$ROOT/scripts" -name '*.sh' -print0 | while IFS= read -r -d '' file; do
  bash -n "$file"
 done

for file in "$ROOT"/*.command; do
  [[ -e "$file" ]] || continue
  bash -n "$file"
done

grep -q 'PrivacyInfo.xcprivacy in Resources' "$ROOT/MacPulse.xcodeproj/project.pbxproj"
grep -q 'MacPulseWidget.appex in Embed App Extensions' "$ROOT/MacPulse.xcodeproj/project.pbxproj"
grep -q 'CODE_SIGN_IDENTITY = "-"' "$ROOT/MacPulse.xcodeproj/project.pbxproj"
! grep -R 'com.apple.security.application-groups' "$ROOT/MacPulse" "$ROOT/MacPulseWidget" >/dev/null 2>&1

if command -v xcodebuild >/dev/null 2>&1; then
  xcodebuild -project "$ROOT/MacPulse.xcodeproj" -list >/dev/null
fi

# `specifier:` belongs to SwiftUI localized interpolation. It must not appear
# inside a ternary/plain String expression, which fails under Xcode 16.
if command -v rg >/dev/null 2>&1; then
  if rg -n '\?.*specifier:' "$ROOT" --glob '*.swift'; then
    echo "ERROR: Found specifier interpolation in a conditional String expression." >&2
    exit 1
  fi
else
  if grep -R -n -E '\?.*specifier:' "$ROOT" --include='*.swift'; then
    echo "ERROR: Found specifier interpolation in a conditional String expression." >&2
    exit 1
  fi
fi

echo "Source validation passed."
