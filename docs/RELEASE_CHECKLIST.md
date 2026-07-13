# Release Checklist

## Source state

- [ ] Working tree contains only intended changes.
- [ ] `MARKETING_VERSION`, build number, `CHANGELOG.md`, and `CITATION.cff` agree.
- [ ] README compatibility and requirements are current.
- [ ] No secrets, provisioning profiles, certificates, or diagnostics are committed.
- [ ] Screenshots are curated under `docs/images/screenshots/` and contain no local user names, private browser content, financial data, or other personal context.

## Automated validation

- [ ] `./scripts/validate-source.sh`
- [ ] `swift test`
- [ ] Xcode Debug build with signing disabled
- [ ] Xcode unit tests
- [ ] signed universal Release build
- [ ] `./scripts/verify-release.sh dist/MacPulse.app`

## Hardware matrix

- [ ] Apple Silicon, current supported macOS
- [ ] Intel integrated graphics, when available
- [ ] Intel + AMD discrete graphics, when available
- [ ] dual-GPU switching scenario, when available
- [ ] representative accelerated Hackintosh, when available
- [ ] GPU-unavailable negative case

## User experience

- [ ] first launch creates no ordinary window
- [ ] login launch steals no focus and sends no notification
- [ ] status-item left/right click behavior
- [ ] pause/resume survives sleep semantics
- [ ] menu-bar text is rate-limited
- [ ] hidden menu-bar recovery path
- [ ] reduced motion, light mode, dark mode, increased contrast
- [ ] Small/Medium/Large Overview widgets
- [ ] Small/Medium CPU and GPU widgets
- [ ] stale and unavailable states

## Distribution

- [ ] Developer ID signature
- [ ] hardened runtime and expected entitlements
- [ ] notarization accepted
- [ ] ticket stapled and validated
- [ ] ZIP recreated after stapling
- [ ] optional DMG created from final app
- [ ] SHA-256 checksums generated
- [ ] checksum files contain asset basenames, not absolute local paths
- [ ] release tag, DMG filename, bundle version, changelog, and citation version agree
- [ ] GitHub release assets include DMG, DMG checksum, ZIP, and consolidated checksums
- [ ] No-Team/ad-hoc build is marked as a prerelease with a Gatekeeper warning
- [ ] clean-machine Gatekeeper launch test
- [ ] release notes include known driver limitations
