# Telemetry Quality Model

MacPulse evaluates telemetry quality along four independent dimensions.

## Availability

Can the current platform expose the requested measurement at all?

- supported and live;
- temporarily stale;
- unavailable.

## Provenance

Which interface and key produced the measurement?

- Mach host counters;
- Mach VM statistics;
- AGXAccelerator IORegistry properties;
- IOAccelerator IORegistry properties;
- fixed-path ioreg fallback;
- documented proxy, such as memory pressure percentage.

## Semantics

Does the field describe an instantaneous percentage, a cumulative counter, a clock, power estimate, temperature, or memory allocation? Values with ambiguous semantics are not silently converted into another category.

## Comparability

A value may be internally useful while not comparable across vendors. For example, unified-memory allocation and discrete VRAM allocation have different resource models. MacPulse labels and documents them without producing a false universal memory-pressure score.

## Acceptance rule

A field enters the user interface only when its source, unit, normalization, plausible range, unavailable behavior, and representative fixture are documented. This rule intentionally favors fewer honest metrics over a larger but misleading dashboard.
