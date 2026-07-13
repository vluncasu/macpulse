# Security Policy

## Supported release line

Security fixes are applied to the latest major release line.

## Reporting

Do not publish credentials, signing material, private IORegistry dumps, or an actionable exploit in a public issue. Send a private report to the maintainer with:

- affected version and commit;
- macOS version and architecture;
- reproducible steps;
- expected and observed behavior;
- security impact;
- minimal proof of concept where appropriate.

## Security design

MacPulse:

- performs read-only Mach and IORegistry access;
- does not install a privileged helper, daemon, or kernel extension;
- does not accept user-controlled command lines;
- invokes only `/usr/sbin/ioreg` with a fixed argument set as a fallback;
- performs no network request;
- persists only bounded local metric snapshots;
- uses `SMAppService` for login registration;
- versions and atomically replaces the shared payload;
- treats driver dictionaries as untrusted input.

See [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md).
