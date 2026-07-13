# Support

MacPulse is an open-source system telemetry utility. Support requests should be reproducible, privacy-preserving, and tied to a specific hardware/software environment.

## Before opening an issue

1. Read `docs/TROUBLESHOOTING.md` and `docs/COMPATIBILITY.md`.
2. Confirm that CPU telemetry works.
3. Open **Settings → Compatibility** and export the diagnostic JSON.
4. Remove any field you do not want to publish.
5. Reproduce the issue using the Balanced sampling profile.

## Include

- MacPulse version and build;
- exact macOS version;
- hardware model and architecture;
- GPU model(s), when known;
- whether the system is an official Mac, Hackintosh, or virtual machine;
- whether native graphics acceleration is working;
- expected and observed behavior;
- concise reproduction steps;
- relevant diagnostic fields or IORegistry key names.

## Do not include

Do not post serial numbers, account identifiers, home-directory paths, IP addresses, MAC addresses, signing certificates, notarization credentials, or complete unrestricted IORegistry dumps.

Security vulnerabilities must be reported according to `SECURITY.md`, not through a public issue.
