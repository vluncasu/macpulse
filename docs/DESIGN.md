# Interface and Product Design Specification

## Design objective

MacPulse is ambient instrumentation. The interface should communicate state on demand without becoming a continuously moving object in peripheral vision.

## Visual hierarchy

1. CPU and GPU circular gauges
2. recent trend
3. CPU composition and memory
4. optional hardware details
5. freshness and sampling metadata

## Motion

- default profile: Calm;
- numeric transitions are smoothed;
- falling values release more slowly than rising values;
- status-bar numeric text updates at most approximately every 1.5 seconds;
- widgets contain no continuous animation;
- macOS Reduce Motion disables gauge interpolation where applicable.

## Startup

The app never presents onboarding or a primary window automatically. Discovery is provided by the menu-bar icon and widget gallery. Settings are explicit, user-invoked surfaces.

## Color

CPU uses the system accent color. GPU uses a restrained purple semantic. Memory uses cyan and system CPU uses orange. Colors are never the only carrier of meaning; every metric has text and accessibility labels.

## Accessibility

- donut gauges expose label and percentage values;
- changing numbers use monospaced digits;
- small labels remain secondary, not hidden;
- system light/dark mode is respected;
- reduced motion is respected;
- unavailable states use text, not color alone.

## Widget composition

Small widgets prioritize one glance. Medium widgets add context. Large Overview adds history and telemetry. Layouts are independently composed rather than geometrically scaled copies.
