# Troubleshooting

## “The project is damaged and cannot be opened due to a parse error”

Use MacPulse 2.0.1 or later. Version 2.0.0 contained unquoted Xcode substitutions such as `$(inherited)` in `project.pbxproj`, which are invalid in that position in the OpenStep project format.

Verify the fixed project on macOS:

```bash
xcodebuild -project MacPulse.xcodeproj -list
```

A successful command prints the project targets and configurations.

## Xcode asks for a Team

The local edition does not require one. In both targets, use **Sign to Run Locally**, or build through:

```bash
./scripts/build-local.sh
```

Do not add App Groups to the no-team configuration.

## The widget is not visible

1. Build and install the app into `/Applications` or `~/Applications`.
2. Open MacPulse once.
3. Wait briefly for extension discovery.
4. Control-click the desktop → **Edit Widgets**.
5. Search for **MacPulse**.
6. If needed, log out and back in after the first local installation.

Confirm that the extension exists:

```bash
ls -la /Applications/MacPulse.app/Contents/PlugIns/MacPulseWidget.appex
```

Confirm signatures:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/MacPulse.app
```

## GPU displays “Unavailable” in the widget

The widget runs in an app-extension sandbox and intentionally avoids the `/usr/sbin/ioreg` process fallback. It uses direct read-only IOKit discovery. A driver that only exposes telemetry through command output may therefore provide GPU data in the menu-bar app but not in the widget.

CPU and memory remain available independently.

## Start at login does not stay enabled

Install MacPulse first, then toggle the option. If native Service Management registration is unavailable, MacPulse uses its local compatibility LaunchAgent. Inspect it with:

```bash
ls -la ~/Library/LaunchAgents/com.macpulse.local.MacPulse.login.plist
```

Disabling the toggle removes that file.

## Gatekeeper rejects the local ZIP on another Mac

Expected. The local build is ad-hoc signed and not notarized. Build it on the destination Mac or create a Developer ID signed and notarized release.
