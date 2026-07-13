# GPU Telemetry Compatibility and Provenance

GPU utilization is the least standardized metric in MacPulse. CPU counters are supplied by stable Mach interfaces; GPU statistics are published by the active graphics driver through IORegistry and vary by operating-system release, GPU family, driver, power state, and system configuration.

## Provider chain

MacPulse evaluates providers in this order:

1. `AGXAccelerator` through direct IOKit access;
2. `IOAccelerator` through direct IOKit access;
3. `/usr/sbin/ioreg -a` as a fixed-path read-only fallback.

The fallback is used only when direct IOKit produces no usable activity sample.

## Device identity

When IOKit provides a registry entry identifier, MacPulse derives a stable process-local identifier from the service class and registry ID. Command-fallback entries use a normalized model-based identifier. Entries are deduplicated before primary-device selection.

## Primary GPU selection

Four policies are available:

- **Automatic:** telemetry completeness, activity, device continuity, and a small discrete-device preference;
- **Highest activity:** favors the largest current utilization;
- **Prefer discrete GPU:** strongly favors AMD/NVIDIA-style discrete identifiers;
- **Prefer integrated GPU:** strongly favors Apple AGX and Intel integrated identifiers.

Automatic continuity avoids oscillation between two devices when activity is nearly equal. The multi-GPU inventory remains visible in Compatibility and the live dashboard.

## Utilization keys

The parser accepts known forms in priority order:

```text
Device Utilization %
GPU Activity(%)
GPU Activity %
GPU Utilization %
GPU Core Utilization
GPU Core Utilization %
Renderer Utilization
GPU Busy
GPU Busy %
```

Values in `(0, 1]` are interpreted as fractions and multiplied by 100. Other finite values are clamped to `[0, 100]`.

## Extended fields

When present in the same telemetry dictionary, MacPulse may expose:

- GPU temperature;
- core and memory clocks;
- fan RPM or fan percentage;
- reported GPU power;
- active, allocated, reclaimable, free, and total memory fields.

These values are descriptive driver output. MacPulse does not claim cross-vendor semantic equivalence. A memory field named `inUseVidMemoryBytes` on an AMD discrete GPU is not treated as equivalent to unified-memory allocation on Apple Silicon.

## Missing, stale, and unavailable

A missing utilization key is not equivalent to zero utilization.

- **Live:** a usable current sample was read.
- **Stale:** a preceding valid sample is retained for at most 15 seconds after a temporary provider failure.
- **Unavailable:** no current sample exists, or the stale retention window expired.

The UI renders unavailable as an em dash rather than `0%`.

## Hackintosh scope

MacPulse is compatible with a Hackintosh only to the extent that the installed macOS graphics stack already exposes a functional `IOAccelerator` service and telemetry dictionary. MacPulse does not enable acceleration, install kexts, inject device properties, patch ACPI, alter framebuffer configuration, or bypass platform security.

Representative validation should record:

- macOS build;
- bootloader version;
- GPU and device ID;
- graphics-related kext versions;
- whether Metal acceleration is functional;
- provider class and accepted key;
- observed range under idle and load.

Do not submit unrestricted registry dumps containing unrelated identifiers.

## Parser extension protocol

A new key is accepted only after:

1. documenting its source hardware and macOS version;
2. documenting the unit and expected range;
3. adding a minimized fixture;
4. adding a parser test;
5. confirming that missing data remains unavailable;
6. checking that the key does not collide with a cumulative counter presented as instantaneous activity.
