# Final Source Validation Record

**Release:** MacPulse 2.1.2 (build 212)  
**Source freeze date:** 2026-07-13

## Executed in the artifact-generation environment

- All Swift files passed frontend syntax parsing.
- Application and widget Info.plists passed XML property-list validation.
- Application and widget entitlement files passed XML property-list validation.
- `PrivacyInfo.xcprivacy` passed XML property-list validation.
- All shell and double-click command scripts passed Bash syntax validation.
- Every application, widget, and shared Swift source is referenced by the Xcode project.
- The widget extension is present in the Embed App Extensions phase.
- The privacy manifest is present in the application Resources phase.
- All portable Swift Package tests passed: **4 tests, 0 failures**.
- All standalone Xcode logic tests passed: **9 tests, 0 failures**.
- The Xcode 16.2 Release build completed for both `arm64` and `x86_64` without compiler warnings.
- The application and embedded widget passed strict code-signature validation with the expected ad-hoc identity.
- The compressed DMG passed `hdiutil verify`, contained `MacPulse.app` and `Applications -> /Applications`, and produced portable SHA-256 files using asset basenames.
- CoreSources contains no broken symbolic links.
- No generated `.build` or `dist` directory is included in release source archives.

Validation host: macOS 14.8.1 (23J30), Intel architecture, Xcode 16.2 (16C5032a).

## Source inventory at freeze

- 32 Swift source/test files, including portable source links;
- approximately 3,466 Swift lines across app, widget, shared model, and tests;
- 11 shell automation scripts;
- 2 double-click macOS command assistants;
- 28 Markdown documentation/governance files;
- application icon set, privacy manifest, entitlements, shared Xcode scheme, CI workflows, and issue templates.

## Validation not completed by this record

The following gates require additional hardware, interactive testing, or Apple distribution credentials and are deliberately not marked as executed here:

- runtime behavior of the independently sampling WidgetKit extension;
- WidgetKit gallery installation and rendering;
- `SMAppService` login registration;
- real IOKit reads across Apple Silicon, Intel integrated, AMD discrete, and Hackintosh hardware;
- Developer ID signing, hardened runtime, notarization, stapling, and Gatekeeper assessment;
- Instruments energy and wakeup measurements;
- VoiceOver and visual accessibility validation.

Run `scripts/release-preflight.sh` on a configured Mac and complete `docs/RELEASE_CHECKLIST.md` before publishing a binary as a production release.

## Integrity policy

The source archive checksum proves archive integrity only. It is not a substitute for code signing or notarization. Public binaries should be generated from a tagged commit, signed with the intended Developer ID, notarized, stapled, and accompanied by checksums.


## Xcode 16.2 compile hotfix

The WidgetKit source no longer uses `specifier:` inside a ternary expression that resolves to plain `String`. The load-average labels now use explicit `String(format:)` formatting. A source validation guard rejects future conditional `specifier:` usage.
