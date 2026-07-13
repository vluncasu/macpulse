#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/doctor.sh"
"$ROOT/scripts/build-local.sh"
"$ROOT/scripts/package-dmg.sh" "$ROOT/dist/MacPulse.app"
