#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/MacPulse.app}"
[[ -d "$APP" ]] || { echo "App not found: $APP" >&2; exit 1; }

TARGET_ROOT="/Applications"
if [[ ! -w "$TARGET_ROOT" ]]; then
  TARGET_ROOT="$HOME/Applications"
  mkdir -p "$TARGET_ROOT"
fi

TARGET="$TARGET_ROOT/MacPulse.app"
rm -rf "$TARGET"
ditto "$APP" "$TARGET"
open "$TARGET"
echo "Installed to $TARGET"
