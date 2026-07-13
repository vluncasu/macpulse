#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0

ok()   { printf '✓ %s\n' "$1"; }
warn() { printf '! %s\n' "$1"; }
fail() { printf '✗ %s\n' "$1"; failures=$((failures + 1)); }

[[ "$(uname -s)" == "Darwin" ]] && ok "Running on macOS" || fail "Xcode application builds require macOS"
command -v xcodebuild >/dev/null 2>&1 && ok "xcodebuild is available" || fail "Install Xcode"
command -v swift >/dev/null 2>&1 && ok "Swift is available" || fail "Swift toolchain missing"
command -v plutil >/dev/null 2>&1 && ok "plutil is available" || fail "plutil missing"
command -v ditto >/dev/null 2>&1 && ok "ditto is available" || fail "ditto missing"
command -v codesign >/dev/null 2>&1 && ok "codesign is available" || fail "codesign missing"
command -v hdiutil >/dev/null 2>&1 && ok "hdiutil is available" || fail "hdiutil missing"
command -v osascript >/dev/null 2>&1 && ok "osascript is available" || fail "osascript missing"

if command -v xcodebuild >/dev/null 2>&1; then
  printf '  %s\n' "$(xcodebuild -version | tr '\n' ' ')"
  if xcodebuild -project "$ROOT/MacPulse.xcodeproj" -list >/dev/null; then
    ok "Xcode project parses correctly"
  else
    fail "Xcode cannot parse MacPulse.xcodeproj"
  fi
fi

for plist in \
  "$ROOT/MacPulse/Info.plist" \
  "$ROOT/MacPulseWidget/Info.plist" \
  "$ROOT/MacPulse/MacPulse.entitlements" \
  "$ROOT/MacPulseWidget/MacPulseWidget.entitlements" \
  "$ROOT/MacPulse/PrivacyInfo.xcprivacy"; do
  plutil -lint "$plist" >/dev/null && ok "Valid plist: ${plist#$ROOT/}" || fail "Invalid plist: $plist"
done

if grep -R "com.apple.security.application-groups" \
  "$ROOT/MacPulse" "$ROOT/MacPulseWidget" >/dev/null 2>&1; then
  fail "No-team build still contains an App Groups entitlement"
else
  ok "No restricted App Groups entitlement"
fi

warn "Local ad-hoc builds are not notarized and are not suitable for public distribution"

if [[ "$failures" -gt 0 ]]; then
  printf '\nDoctor found %d blocking issue(s).\n' "$failures" >&2
  exit 1
fi

printf '\nMacPulse local build environment is ready. No Team ID is required.\n'
