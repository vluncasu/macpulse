# Validation Plan

## Automated validation

- Swift parser/filter package tests on each push;
- Xcode Debug build with signing disabled;
- Xcode unit tests;
- XML plist lint;
- shell syntax validation;
- universal Release artifact workflow;
- release signature and architecture inspection script.

## Hardware matrix

At minimum, a public release should be exercised on:

1. Apple Silicon Mac;
2. Intel Mac with integrated graphics;
3. Intel Mac with AMD discrete graphics;
4. accelerated Hackintosh or equivalent IOAccelerator test contribution;
5. unsupported/VM environment to verify unavailable semantics.

## Functional cases

- silent cold launch;
- second-instance reopen;
- menu item hidden and URL reopen;
- pause/resume;
- force refresh;
- three visual profiles;
- three sampling profiles;
- all widget products and sizes;
- local persistence failure presentation;
- sleep/wake while running;
- sleep/wake while manually paused;
- Low Power Mode;
- serious thermal simulation where practical;
- multi-GPU switching;
- no network activity.

## Comparison protocol

Use a repeatable workload sequence:

1. 60 seconds idle;
2. 60 seconds CPU-only load;
3. 60 seconds GPU/Metal load;
4. 60 seconds combined load;
5. 60 seconds recovery.

Record MacPulse, Activity Monitor GPU History, timestamps, hardware, macOS build, power mode, and active display configuration. Compare trend direction, onset, recovery, and unavailable/stale transitions.

## Privacy manifest validation

Confirm that `PrivacyInfo.xcprivacy` is included in the application Resources build phase, contains no tracking domains or collected-data declarations, and includes only required-reason API categories actually used by the product. Generate and inspect Xcode's privacy report for release archives.
