# Energy and Thermal Design

MacPulse is a persistent utility, so its own observation cost is part of product correctness.

## Control variables

The adaptive policy uses:

- selected sampling profile;
- dashboard visibility;
- sustained low CPU/GPU activity;
- Low Power Mode;
- process thermal state;
- sleep and wake notifications.

CPU and memory reads are inexpensive local counter snapshots. GPU enumeration and property parsing are scheduled independently because they can be comparatively more expensive and driver-dependent.

## Profiles

| Profile | Visible dashboard | Active background | Sustained idle background |
|---|---:|---:|---:|
| Responsive | CPU ~0.50 s / GPU ~0.65 s | CPU ~0.90 s / GPU ~1.30 s | CPU ~2 s / GPU ~4 s |
| Balanced | CPU ~0.75 s / GPU ~0.90 s | CPU ~1.40 s / GPU ~2.20 s | CPU ~3 s / GPU ~6 s |
| Efficient | CPU ~1.10 s / GPU ~1.60 s | CPU ~2.80 s / GPU ~4.50 s | CPU ~6 s / GPU ~12 s |

Values are target intervals and not hard real-time deadlines.

## Overrides

In background Low Power Mode, the main loop targets approximately 6 seconds and GPU polling approximately 10 seconds. Serious and critical thermal states impose stronger backoff. Keeping the dashboard open retains a bounded interactive rate so that the user can still diagnose load.

## Idle hysteresis

MacPulse does not change to an idle schedule after one quiet sample. It counts consecutive samples below the CPU/GPU threshold while the dashboard is closed. This avoids rapid interval oscillation near the threshold.

## Sleep and wake

Before system sleep, the monitor records whether it was running and stops its task. After wake, Mach deltas and visual smoothers are re-primed before sampling resumes. A user-paused monitor remains paused.

## Widget cost

The app writes the shared payload at a bounded rate and requests widget timeline reloads only after a meaningful state change, a minimum reload gap, or a heartbeat interval. The widget extension does not run a private polling loop.

## Evaluation protocol

Energy assessment should compare MacPulse closed, dashboard visible, Balanced background, Efficient background, Low Power Mode, and serious thermal simulation where available. Record:

- Mac model and battery/power state;
- macOS version;
- profile;
- primary GPU provider;
- mean process CPU over at least 10 minutes;
- wakeups and energy impact from Activity Monitor or Instruments;
- whether the menu-bar percentage text is enabled;
- whether widgets are installed.

A performance optimization is accepted only if it does not convert missing telemetry into misleading data or break interactive responsiveness.
