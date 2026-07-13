#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./scripts/doctor.sh
./scripts/validate-source.sh
swift test
./scripts/build-local.sh
./scripts/verify-release.sh dist/MacPulse.app

echo "Local no-team release preflight completed."
