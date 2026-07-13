#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This project must be opened on macOS."
  exit 1
fi
open "$ROOT/MacPulse.xcodeproj"
