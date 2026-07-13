#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

clear
cat <<'TEXT'
MacPulse local build and DMG creation

This process builds MacPulse with an ad-hoc local signature and creates a
standard drag-to-install disk image. No Apple Developer Team ID is required.

The resulting DMG is suitable for installation on this Mac. Public distribution
without Gatekeeper warnings requires Developer ID signing and Apple notarization.
TEXT

printf '\n'
"$ROOT/scripts/doctor.sh"
"$ROOT/scripts/build-local.sh"
"$ROOT/scripts/package-dmg.sh" "$ROOT/dist/MacPulse.app"

printf '\nBuild products:\n'
printf '  Application: %s\n' "$ROOT/dist/MacPulse.app"
printf '  DMG:         %s\n' "$(find "$ROOT/dist" -maxdepth 1 -name 'MacPulse-*.dmg' -print | sort | tail -n 1)"
printf '\nOpening the dist directory.\n'
open "$ROOT/dist"

printf '\nPress Return to close this window.\n'
read -r _
