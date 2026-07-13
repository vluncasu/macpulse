#!/bin/bash
set -euo pipefail

cat <<'TEXT'
MacPulse signing modes

LOCAL / NO TEAM ID (default)
  ./scripts/build-local.sh

This uses an ad-hoc signature, removes restricted App Group entitlements, and
lets the widget sample system metrics independently. It is intended for use on
the Mac where it is built.

PUBLIC DISTRIBUTION
A paid Apple Developer membership, Developer ID Application certificate, and
notarization are required. Create a separate distribution configuration before
publishing. Do not distribute the local ad-hoc build as a trusted download.
TEXT
