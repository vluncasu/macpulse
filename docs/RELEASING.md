# Release Procedure

## 1. Release classes

MacPulse defines two release classes.

### 1.1 Local release

A local release uses ad-hoc signing and requires no Apple Developer Team ID. It is intended for execution on the machine that produced it.

Products:

```text
MacPulse.app
MacPulse-<version>-local.zip
MacPulse-<version>.dmg
SHA-256 checksum files
```

### 1.2 Public direct-distribution release

A public direct-distribution release requires:

- Apple Developer Program membership;
- Developer ID Application certificate;
- hardened runtime configuration as required by the release policy;
- Apple notarization;
- stapling;
- final Gatekeeper assessment.

## 2. Version update

Update both Xcode build settings:

```text
MARKETING_VERSION
CURRENT_PROJECT_VERSION
```

Update:

- `CHANGELOG.md`;
- `CITATION.cff`;
- documentation containing explicit artifact names;
- release notes.

## 3. Validation

Run:

```bash
./scripts/clean.sh
./scripts/validate-source.sh
swift test
./scripts/doctor.sh
./scripts/build-local.sh
codesign --verify --deep --strict --verbose=2 dist/MacPulse.app
```

Perform hardware validation on representative Apple Silicon, Intel integrated, Intel/AMD discrete, and Hackintosh systems where available.

## 4. Local artifact generation

```bash
./scripts/build-and-package.sh
```

Verify:

```bash
hdiutil verify dist/MacPulse-<version>.dmg
shasum -a 256 dist/MacPulse-<version>.dmg
```

## 5. Public release sequence

1. build the Release application;
2. sign the application and embedded extension with Developer ID Application;
3. verify nested signatures;
4. submit for notarization;
5. staple the application;
6. create the final DMG;
7. sign and notarize the DMG according to the release policy;
8. staple and validate the DMG;
9. verify with `spctl`;
10. publish the DMG and checksum.

Detailed commands are documented in [DISTRIBUTION.md](DISTRIBUTION.md).

## 6. GitHub release layout

The release tag and application version must agree. For version `2.1.2`, use tag `v2.1.2` and upload these local files as release assets:

```text
dist/MacPulse-2.1.2.dmg
dist/MacPulse-2.1.2.dmg.sha256
dist/MacPulse-2.1.2-local.zip
dist/SHA256SUMS.txt
```

GitHub exposes the DMG at:

```text
https://github.com/vluncasu/macpulse/releases/download/v2.1.2/MacPulse-2.1.2.dmg
```

The `dist/` prefix is a local filesystem path and must not appear in the public asset URL. GitHub release assets are addressed by their basenames.

An ad-hoc No-Team binary must be published as a prerelease with an explicit Gatekeeper and notarization warning. Only a Developer ID signed, notarized, stapled, and Gatekeeper-accepted artifact may be presented as a normal public release.
