# Product Specification

## Product statement

MacPulse is a quiet native macOS telemetry utility for users who need CPU and GPU awareness without maintaining a distracting monitoring window.

## Primary users

- developers validating compute and graphics workloads;
- creators monitoring rendering, encoding, CAD, and 3D applications;
- owners of Intel/AMD Macs who need driver-exposed GPU detail;
- Apple Silicon users who need a minimal system overview;
- Hackintosh maintainers validating an already accelerated graphics stack;
- technical support teams collecting privacy-preserving local diagnostics.

## Jobs to be done

1. Determine whether CPU or GPU is the current bottleneck.
2. Observe a workload without placing a persistent dashboard over it.
3. Verify that macOS exposes GPU acceleration telemetry.
4. Distinguish current load from cached/reclaimable memory allocation.
5. Keep a calm system overview on the desktop.
6. Start monitoring automatically without a login interruption.

## Functional requirements

- Native CPU utilization with user/system composition.
- Driver-exposed GPU utilization with explicit provenance.
- Multi-GPU enumeration and deterministic primary selection.
- Quiet menu-bar status item and optional rate-limited text.
- Real-time popover with responsive but nonaggressive motion.
- Small, medium, and large overview widgets plus focused CPU/GPU widgets.
- Atomic app/widget state sharing.
- Login-item control.
- Local diagnostics export.
- Universal Intel/Apple Silicon release build.

## Nonfunctional requirements

- No network access, analytics, privileged helper, or kernel extension.
- No window or focus theft at login.
- Missing telemetry never represented as zero.
- Bounded history, persistence, and widget reload behavior.
- Reduced Motion and semantic appearance support.
- Test fixtures for new telemetry keys.
- Reproducible release checklist and checksums.

## Explicit non-goals

- fan control, undervolting, overclocking, or power-limit control;
- process-level GPU attribution;
- private-framework dependency;
- kernel or bootloader patching;
- remote monitoring or cloud dashboards;
- guaranteed identical metrics across GPU vendors;
- a one-second WidgetKit redraw guarantee.

## Release acceptance criteria

A release is acceptable only when:

- CPU and parser/filter tests pass;
- the app launches silently as an accessory process;
- login registration can be enabled and disabled;
- widget sharing works in a signed build;
- no unsupported GPU produces a fabricated `0%`;
- both architectures are present in the public direct-distribution binary;
- signatures and notarization validate;
- diagnostics omit declared personal identifiers;
- documentation and version metadata agree.
