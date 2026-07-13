# Frequently Asked Questions

## Is the desktop widget truly live every second?

No. The application can acquire and persist telemetry continuously while running, but WidgetKit owns desktop rendering schedules. The menu-bar dashboard is the real-time interface; widgets show the newest snapshot macOS permits them to render.

## Why does GPU show unavailable while CPU works?

CPU data comes from Mach counters. GPU activity depends on properties published by the active graphics driver. Some drivers, power states, virtual machines, or nonaccelerated configurations do not publish a usable utilization field.

## Why can GPU memory look almost full at idle?

Driver-reported allocation may include caches and reclaimable memory. MacPulse separates reclaimable fields when the driver exposes them and avoids treating all allocated bytes as irreducibly occupied application memory.

## Why is an AMD memory clock high when GPU activity is low?

Clock policy belongs to the graphics driver and can be affected by display topology, refresh rate, resolution, and power state. MacPulse reports the value but does not diagnose or alter the policy.

## Does MacPulse control fans or overclocking?

No. It is read-only telemetry software.

## Does it need administrator privileges?

The application does not require administrator privileges. Building, installing Xcode, or placing software into protected system locations may involve normal macOS authorization outside the app.

## Does Start at Login install a LaunchAgent?

No. MacPulse registers the main application through the native ServiceManagement API.

## Is Hackintosh supported?

Yes, when macOS already has working accelerated Intel/AMD graphics and publishes compatible IOAccelerator statistics. MacPulse does not make unsupported graphics hardware work.

## Why is the app not in the Dock?

It is an accessory application designed for the menu bar and widgets. Opening the app again reveals the popover without creating a normal Dock-resident window.

## Can I hide the menu-bar icon and use only widgets?

Yes. Keep widget synchronization enabled, then disable the menu-bar item. Opening MacPulse again temporarily restores an access point so Settings remain reachable.

## What data leaves the Mac?

None through MacPulse. The app has no networking feature. Diagnostic export is explicit and local.
