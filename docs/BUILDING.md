# Building MacPulse 2.1.2

## 1. Requirements

- macOS 13 or newer;
- Xcode 15 or newer;
- Xcode command-line tools;
- sufficient disk space for Xcode DerivedData;
- no Apple Developer Team ID for the local ad-hoc build.

Confirm the active developer directory:

```bash
xcode-select -p
xcodebuild -version
```

When multiple Xcode installations are present, select the intended version:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## 2. Environment validation

```bash
./scripts/doctor.sh
```

The script verifies:

- operating system;
- Xcode and Swift availability;
- plist parsing;
- Xcode project parsing;
- entitlements;
- absence of App Group requirements in the no-team edition;
- required packaging commands.

## 3. Local Release build

```bash
./scripts/build-local.sh
```

The script invokes `xcodebuild` with:

```text
configuration: Release
destination: platform=macOS
architectures: arm64 x86_64
code-signing identity: -
team: unset
provisioning profile: unset
```

Products are copied to:

```text
dist/MacPulse.app
dist/MacPulse-2.1.2-local.zip
dist/SHA256SUMS.txt
```

## 4. Installation

```bash
./scripts/install-local.sh
```

The installer copies the application to `/Applications` when writable, otherwise to `~/Applications`.

The combined interactive workflow is:

```text
Build and Install MacPulse.command
```

## 5. DMG generation

The complete build-and-package workflow is:

```text
Build and Create DMG.command
```

or:

```bash
./scripts/build-and-package.sh
```

The DMG is written to:

```text
dist/MacPulse-2.1.2.dmg
```

The image contains `MacPulse.app` and a symbolic link to `/Applications`. Installation is performed by dragging the application onto the Applications link.

An existing application can be packaged independently:

```bash
./scripts/package-dmg.sh ./dist/MacPulse.app
```

## 6. Xcode build

1. Open `MacPulse.xcodeproj`.
2. Select the shared `MacPulse` scheme.
3. Select `My Mac` as the run destination.
4. Leave Team unset.
5. Build or run.

The project uses ad-hoc signing for the local edition.

## 7. Clean build

```bash
./scripts/clean.sh
./scripts/build-local.sh
```

The clean script removes repository-local build products and DerivedData.

## 8. Source validation

```bash
./scripts/validate-source.sh
swift test
```

On macOS, a full validation also includes:

```bash
xcodebuild \
  -project MacPulse.xcodeproj \
  -scheme MacPulse \
  -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  PROVISIONING_PROFILE_SPECIFIER= \
  build
```

## 9. Signature verification

```bash
codesign --verify --deep --strict --verbose=2 dist/MacPulse.app
codesign -dv --verbose=4 dist/MacPulse.app
```

The ad-hoc identity appears as `Signature=adhoc` or an equivalent local-signature representation.

## 10. Public distribution

Do not publish the local ZIP or DMG as a notarized release. Public distribution requires Developer ID signing and Apple notarization. See [DISTRIBUTION.md](DISTRIBUTION.md).
