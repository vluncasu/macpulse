# Architecture

## 1. System boundary

MacPulse is a user-session accessory application and a WidgetKit extension. It is not a daemon, privileged service, kernel component, or hardware controller. Its boundary contains read-only system telemetry acquisition, local transformation, bounded persistence, and presentation.

## 2. Runtime components

### 2.1 Main application

`MacPulseMain` constructs `NSApplication`, selects `.accessory` activation policy, assigns `AppDelegate`, and enters the run loop. `LSUIElement=true` prevents a Dock icon and ordinary app-switcher presence.

`AppDelegate` owns long-lived services:

- `SettingsStore`
- `MonitorStore`
- `LaunchAtLoginController`
- `StatusItemController`
- `SettingsWindowController`

No window is created or presented during ordinary startup.

### 2.2 Telemetry coordinator

`MonitorStore` is isolated to the main actor because its state feeds SwiftUI. CPU and memory acquisition are low-cost synchronous operations. GPU acquisition is dispatched at utility priority because IOKit enumeration and the command fallback may take longer.

The coordinator maintains:

- smoothed and raw CPU/GPU values;
- latest multi-GPU inventory;
- selected primary GPU continuity;
- live history;
- idle hysteresis;
- sleep/wake state;
- persistence and WidgetKit reload budgets.

Overlapping sample cycles are rejected by an explicit `isSampling` guard.

### 2.3 GPU provider chain

The provider performs direct IOKit enumeration in this order:

1. `AGXAccelerator`
2. `IOAccelerator`

Each registry entry is identified by `IORegistryEntryGetRegistryEntryID`, snapshotted with `IORegistryEntryCreateCFProperties`, and parsed as untrusted version-dependent input. If no usable direct sample exists, a fixed `/usr/sbin/ioreg` property-list command is used.

The parser:

- recursively locates candidate telemetry dictionaries with a depth bound;
- accepts numeric Foundation and Swift scalar types;
- accepts numeric string prefixes;
- normalizes fraction-form percentages;
- rejects non-finite values;
- rejects implausible temperatures;
- does not infer total VRAM from potentially overcommitted allocation counters;
- distinguishes active, allocated, reclaimable, free, and total memory when exposed.

### 2.4 Multi-GPU selection

A primary device is selected from the deduplicated device inventory. Four modes are available:

- Automatic
- Highest activity
- Prefer discrete GPU
- Prefer integrated GPU

Automatic selection scores telemetry completeness, current activity, direct-vs-command source, device hints, and continuity with the previous primary identifier. Continuity prevents rapid switching between integrated and discrete entries when their scores are nearly equal.

### 2.5 Adaptive scheduler

The main-loop and GPU intervals are independently selected. Inputs are:

- sampling profile;
- popover visibility;
- number of consecutive low-load samples;
- Low Power Mode;
- thermal state.

The scheduler is hysteretic: a single low sample does not immediately move the process into the idle regime. Thermal serious/critical states override the user profile.

### 2.6 Persistence

`SharedSnapshotStore` encodes a versioned JSON payload using millisecond date precision and sorted keys. The no-team edition stores it atomically in the process-local Application Support directory, with local `UserDefaults` as a fallback.

The stored history is downsampled to a bounded number of points before encoding. This prevents the shared payload from scaling with process lifetime.

### 2.7 Widget extension

The extension is read-only. It loads one immutable payload while producing a timeline and renders one of three widget products. It performs no telemetry acquisition and no command execution.

Widget rendering and application acquisition are deliberately decoupled. This prevents a widget timeline request from becoming a hidden high-frequency sampling mechanism.

## 3. Data model

`SystemSnapshot` contains:

- timestamp and monotonic sequence;
- CPU snapshot;
- selected GPU snapshot;
- complete detected GPU array;
- memory snapshot;
- machine description;
- thermal and Low Power state;
- effective interval and session uptime.

GPU optionality is semantic. `usage=nil` means unavailable; `usage=0` means a valid zero-activity sample.

## 4. State transitions

### GPU freshness

```text
unavailable --valid sample--> live
live --temporary read failure--> stale
stale --valid sample--> live
stale --hold timeout--> unavailable
```

### acquisition

```text
paused --start--> live/adaptive
running --sleep--> paused (remember previous state)
paused-from-sleep --wake--> running
manually paused --sleep/wake--> remains paused
```

## 5. Failure semantics

- Mach CPU failure retains the preceding sample and refreshes load averages.
- Mach VM failure returns an explicit zeroed fallback with known total memory.
- GPU parsing failure does not crash the cycle.
- command fallback failure returns no candidates.
- Local persistence failure is exposed in Settings and diagnostics.
- widget cache version mismatch is rejected.

## 6. Concurrency

The UI model remains main-actor isolated. GPU reads use a detached utility task with immutable captured settings. Results return to the main actor before state mutation. Persistence is synchronous but bounded to a small atomic file and batched at a minimum interval.

## 7. Dependency policy

Production code has no third-party runtime dependency. This reduces supply-chain surface, app size, startup variance, and compatibility risk.

## 8. Extension principles

A new metric provider must:

1. define data provenance;
2. state units and normalization;
3. distinguish absent from zero;
4. provide representative tests;
5. document energy cost;
6. avoid privileged access unless introduced as a separately reviewed architecture.


## No-team widget boundary

The WidgetKit extension does not consume the application persistence file. It performs a short CPU delta observation and direct read-only IOKit sampling during timeline generation. This removes the need for a provisioned App Group while preserving a native widget extension.
