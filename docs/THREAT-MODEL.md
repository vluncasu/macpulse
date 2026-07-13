# Threat Model

## Assets

- integrity of the user session;
- privacy of local system information;
- integrity of the signed app and widget;
- login-item registration state;
- process-local snapshot and widget-local history.

## Trust boundaries

- macOS kernel/Mach counters;
- IORegistry property dictionaries supplied by drivers;
- fixed system executable `/usr/sbin/ioreg`;
- app/WidgetKit extension process boundary;
- release-signing pipeline.

## Threats and mitigations

### Malformed driver properties

Properties are treated as untrusted. Parsing is optional, type-checked, depth-bounded, range-checked, and fail-soft.

### Command injection

No user-controlled executable path or argument is accepted. The fallback invokes the fixed path with a fixed argument set.

### Privilege escalation

No privileged helper, Authorization Services request, setuid executable, or daemon exists.

### Data exfiltration

No network implementation exists. Diagnostic export is user-initiated and local.

### Persistence corruption

Payloads are versioned and atomically replaced. Decode or schema failure results in an empty payload rather than execution or partial interpretation.

### Supply chain

Production has no third-party runtime package. GitHub Actions are pinned to verified commit SHAs with version comments. Maintainers must review upstream release notes before updating those pins.
