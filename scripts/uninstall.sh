#!/bin/bash
set -euo pipefail

osascript -e 'tell application "MacPulse" to quit' >/dev/null 2>&1 || true

LABEL="com.macpulse.local.MacPulse.login"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
/bin/launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
rm -f "$PLIST"

rm -rf /Applications/MacPulse.app "$HOME/Applications/MacPulse.app"
rm -f "$HOME/Library/Preferences/com.macpulse.local.MacPulse.plist"
rm -f "$HOME/Library/Preferences/com.terabitlab.MacPulse.plist"
rm -rf "$HOME/Library/Application Support/MacPulse"

echo "Removed MacPulse, its local preferences, Application Support data, and login fallback."
