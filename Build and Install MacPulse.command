#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

clear
cat <<'TEXT'
MacPulse 2.1.2 — No-Team Local Build

This builds MacPulse and its WidgetKit extension using Apple's local ad-hoc
signature ("Sign to Run Locally"). No Apple Developer Team ID, paid account,
provisioning profile, or App Group registration is required.

The resulting app is intended for this Mac. Public distribution still requires
Developer ID signing and Apple notarization.
TEXT

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: MacPulse must be built on macOS with Xcode." >&2
  read -r -p "Press Return to close…" _
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Xcode is unavailable. Install Xcode, open it once, and accept its license." >&2
  read -r -p "Press Return to open the project…" _
  open "$ROOT/MacPulse.xcodeproj"
  exit 1
fi

./scripts/doctor.sh
./scripts/build-local.sh
./scripts/verify-release.sh dist/MacPulse.app
./scripts/install-local.sh dist/MacPulse.app

cat <<'TEXT'

MacPulse was installed and opened.

To add a widget:
1. Control-click the desktop and choose Edit Widgets.
2. Search for MacPulse.
3. Add Overview, CPU, or GPU in an available size.

The first widget reading may take a moment because CPU usage is measured over a
short observation interval. Widget refresh timing is controlled by macOS.

Start at login:
Open MacPulse Settings and enable Start MacPulse at login. MacPulse first uses
SMAppService and automatically falls back to a user LaunchAgent when a locally
signed build cannot register through Service Management.
TEXT

read -r -p "Press Return to close…" _
