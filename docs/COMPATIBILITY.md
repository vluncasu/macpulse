# Compatibility

## Supported baseline

- macOS 13 Ventura or newer
- `arm64` and `x86_64`
- Xcode 15 or newer for development

## Apple Silicon

CPU and memory telemetry are supported. GPU activity is read from `AGXAccelerator` only when the current driver publishes a recognized field. Unified-memory properties may describe allocation domains that do not map to dedicated VRAM.

## Intel Macs

CPU and memory telemetry are supported. Intel integrated and AMD discrete graphics are queried through `IOAccelerator`. On dual-GPU MacBook Pro systems, MacPulse enumerates all usable accelerators and applies the selected primary-device policy.

Reading registry properties is not intended to force the discrete GPU online. Actual switching behavior remains controlled by macOS and active applications.

## Hackintosh

MacPulse is compatible with Hackintosh systems when all of the following are true:

1. macOS has functional hardware acceleration;
2. the active Intel or AMD driver publishes `IOAccelerator` statistics;
3. the application is allowed to read the registry entry;
4. the keys use a recognized or compatible representation.

MacPulse cannot reliably prove that a system is a Hackintosh because SMBIOS identity may intentionally emulate a Mac model. It therefore labels unknown x86 systems as **Intel-compatible macOS system** rather than making a definitive classification.

MacPulse does not:

- patch OpenCore;
- add device properties;
- alter framebuffer connectors;
- install WhateverGreen, Lilu, or any kext;
- enable unsupported NVIDIA acceleration;
- modify ACPI;
- write NVRAM.

### Expected matrix

| Configuration | Expected behavior |
|---|---|
| Native Intel iGPU acceleration | CPU + likely GPU activity |
| Native supported AMD acceleration | CPU + likely GPU activity and optional extended fields |
| iGPU headless plus AMD display output | both entries may appear; selected policy determines primary |
| unsupported modern NVIDIA | CPU works; GPU likely unavailable |
| VESA/software framebuffer | CPU works; GPU unavailable |
| macOS VM without accelerated passthrough | CPU works; GPU unavailable |

## Multi-GPU policy

Automatic mode considers:

- valid utilization;
- telemetry completeness;
- direct IOKit source preference;
- current utilization;
- prior selected device;
- discrete/integrated hints.

Manual preference modes are heuristic because registry naming is not standardized.

## Diagnostic commands

```bash
ioreg -a -r -d 2 -w 0 -c AGXAccelerator > ~/Desktop/agx.plist
ioreg -a -r -d 2 -w 0 -c IOAccelerator > ~/Desktop/ioaccelerator.plist
```

Search the property lists for `PerformanceStatistics`, `Device Utilization %`, or `GPU Activity(%)`.

Do not run MacPulse as root. Elevated privilege is neither required nor supported.
