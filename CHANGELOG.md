# Changelog

## 2.1.2

- Added a complete drag-to-install DMG workflow.
- Added `Build and Create DMG.command` for local build and packaging without a Team ID.
- Added a verified read-write-to-compressed DMG pipeline with an Applications symbolic link.
- Rewritten GitHub README in formal technical English.
- Added a distribution document distinguishing local DMG generation from Developer ID distribution.
- Corrected artifact names and build documentation for version 2.1.2.
- Added portable release checksums and exact GitHub DMG download documentation.
- Hardened GitHub Actions and added DMG output to the manual artifact workflow.
- Replaced the deprecated save-panel file-type API for clean macOS 13+ builds.
- Converted Xcode unit tests to standalone logic tests so CI cannot hang on the menu-bar app lifecycle.
- Added a compact, privacy-reviewed product tour with the menu dashboard first, desktop widgets second, and the complete widget gallery collapsed by default.
- Hardened DMG packaging against stale mounted release images and same-name volume conflicts.
- Added complete, privacy-cropped screenshots for every Settings surface and clarified that DMG binaries are distributed through GitHub Releases rather than package registries.

## 2.1.1

- Corrected repository references to `vluncasu/macpulse`.

## 2.1.0

- Improved GPU telemetry merging and primary-device selection.
- Added configurable visible application, CPU, and GPU labels.
- Added power telemetry surfaces and explicit unavailable states.
- Added TerabitLab attribution and website link.

## 2.0.2

- Corrected Swift string formatting in the WidgetKit target for Xcode 16.2.

## 2.0.1

- Repaired the Xcode project file.
- Added the no-team ad-hoc signing configuration.
- Removed the App Group dependency from the local edition.

## 2.0.0

- Added adaptive sampling, multi-GPU support, WidgetKit extensions, local persistence, tests, and technical documentation.
