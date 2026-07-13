# Startup and Background Behavior

## Application type

MacPulse is an `LSUIElement` accessory application. It has no ordinary Dock presence and no default primary window.

## Manual launch

Opening MacPulse starts the telemetry engine and installs the configured menu-bar item. It does not steal focus or open Settings. Reopening an already running instance asks the existing process to reveal the popover.

## Start at login

The setting uses `SMAppService.mainApp` on macOS 13+. Registration may require user approval under System Settings → General → Login Items.

No independent helper executable is installed. The main app itself is launched by macOS in the user session.

## Sleep and wake

Before sleep, MacPulse records whether monitoring was active and cancels the sampling loop. On wake it resets CPU baselines and visual filters, then resumes only if it was active before sleep. A manually paused engine remains paused.

## Hidden menu-bar item

A user may hide the status item while retaining widgets and background monitoring. Opening `macpulse://open` or reopening the application temporarily creates the item so the popover can be anchored. It is removed again after closure when the preference remains hidden.


## Local-signature fallback

The compatibility LaunchAgent invokes `/usr/bin/open -gj` for the installed app bundle. It is written only after the user enables the toggle, requires no elevated privileges, and is removed by disabling the toggle or running `scripts/uninstall.sh`.
