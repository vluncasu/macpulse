# User Guide

## Open MacPulse

Launch it from Applications or Spotlight. MacPulse does not open a window. Click the gauge icon in the menu bar.

## Start automatically

Open Settings → General and enable **Start MacPulse at login**. Approve it in System Settings if macOS requests confirmation. Future login launches remain silent.

## Add widgets

1. Control-click the desktop.
2. Select **Edit Widgets**.
3. Search for **MacPulse**.
4. Choose Overview, CPU, or GPU.
5. Choose an available size and place it.

## Keep the interface calm

Use:

- Menu bar: Icon only
- Visual response: Calm
- Sampling: Balanced

These are the defaults.

## Save battery

Choose Efficient and keep Respect Low Power Mode enabled. Sampling automatically becomes faster when the dashboard opens.

## Multiple GPUs

Automatic is recommended. For testing, choose Highest activity or a discrete/integrated preference. The selected GPU is marked in the live dashboard.

## Understand states

- **Live:** current driver sample
- **Stale:** last valid sample temporarily held after a missing read
- **Unavailable:** the driver does not currently expose a recognized utilization value

Unavailable does not indicate hardware failure.

## Export diagnostics

Settings → Compatibility → Export JSON. The report is local and intentionally excludes account and network identifiers.
