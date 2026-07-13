#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -rf "$ROOT/.build" "$ROOT/dist"
find "$ROOT" -name '.DS_Store' -delete
echo "Removed generated build and distribution artifacts."
