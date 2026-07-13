# Distribution and DMG Packaging

## 1. Purpose

This document distinguishes local ad-hoc builds from publicly distributable macOS releases and defines the repository's DMG packaging process.

## 2. DMG contents

The generated disk image contains:

```text
MacPulse.app
Applications -> /Applications
```

The symbolic link allows the conventional installation workflow: the user drags `MacPulse.app` onto `Applications`.

## 3. Local DMG generation

No Apple Developer Team ID is required to create a DMG for local use.

Run:

```bash
./scripts/build-and-package.sh
```

or double-click:

```text
Build and Create DMG.command
```

The build is ad-hoc signed. The resulting image is appropriate for installation on the machine that produced it.

## 4. Packaging an existing application

```bash
./scripts/package-dmg.sh /absolute/path/to/MacPulse.app
```

The script:

1. validates the application bundle;
2. reads the version from `Contents/Info.plist`;
3. creates a temporary read-write HFS+ image;
4. copies the application and creates the `/Applications` symbolic link;
5. applies Finder window metadata when Finder automation succeeds;
6. converts the image to compressed UDZO format;
7. verifies the image with `hdiutil verify`;
8. writes a SHA-256 checksum.

The Finder layout step is non-critical. If Finder automation is denied, the image remains installable and contains the required application and Applications link.

## 5. Gatekeeper requirements

A DMG does not replace code signing or notarization. A public release should use the following sequence:

```text
Build Release application
Sign application and embedded extensions with Developer ID Application
Verify nested signatures
Submit application or archive for notarization
Staple the notarization ticket
Create the final DMG
Sign the DMG when required by the release policy
Submit the DMG for notarization
Staple the DMG
Verify with spctl and codesign
Publish DMG and SHA-256 checksum
```

Required tools are included with Xcode or macOS:

```text
codesign
notarytool
stapler
spctl
hdiutil
```

Developer ID signing and notarization require an Apple Developer Program membership.

## 6. Verification commands

Application signature:

```bash
codesign --verify --deep --strict --verbose=2 MacPulse.app
codesign -dv --verbose=4 MacPulse.app
```

Gatekeeper assessment:

```bash
spctl --assess --type execute --verbose=4 MacPulse.app
```

Disk-image integrity:

```bash
hdiutil verify MacPulse-2.1.2.dmg
```

Checksum:

```bash
shasum -a 256 MacPulse-2.1.2.dmg
```

Stapling validation:

```bash
xcrun stapler validate MacPulse.app
xcrun stapler validate MacPulse-2.1.2.dmg
```

## 7. Limitations of the no-team edition

The no-team edition deliberately omits entitlements that require a provisioning profile. Widget data is sampled independently by the extension. Ad-hoc signatures do not provide a verifiable publisher identity and are not accepted as a public distribution mechanism.
