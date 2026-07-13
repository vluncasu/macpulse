# Accessibility

MacPulse is designed as a glanceable utility, but visual compactness must not make system state inaccessible.

## Implemented behavior

- The menu-bar button publishes an accessibility label containing monitoring state and CPU/GPU activity.
- Donut gauges expose text values and do not rely on hue alone.
- Live, stale, unavailable, paused, low-power, and thermal states have textual representations.
- Percentage typography uses monospaced digits to reduce layout movement.
- SwiftUI transitions honor the system Reduce Motion setting.
- Light and dark appearances use semantic system materials and colors.
- Controls use native labels, toggles, pickers, buttons, and keyboard conventions.
- Right-click menu actions include standard keyboard equivalents where appropriate.

## Motion policy

The live dashboard filters numeric input and animates toward filtered values. Reduced Motion disables nonessential animated transitions. Widgets use static rendering for each timeline entry.

## Validation checklist

- Navigate Settings using keyboard only.
- Read the status item and primary dashboard controls with VoiceOver.
- Verify unavailable GPU telemetry is announced as unavailable, not zero.
- Verify 200% display scaling does not truncate critical state labels.
- Verify Increased Contrast and Reduce Transparency retain readable boundaries.
- Verify Reduce Motion removes attention-seeking transitions.
- Verify light/dark mode and accent-color changes preserve contrast.
