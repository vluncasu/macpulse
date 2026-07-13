# Contributing

## Non-negotiable invariants

1. Missing telemetry remains optional and is never silently converted to zero.
2. Launch remains silent and accessory-only.
3. No network dependency or analytics is introduced without explicit architectural review.
4. Background energy impact remains bounded and measured.
5. Intel and Apple Silicon builds remain valid.
6. UI supports light mode, dark mode, accessibility labels, and Reduce Motion.
7. GPU parsing treats all driver data as untrusted and version-dependent.

## Development workflow

```bash
swift test
./scripts/validate-source.sh
make test
```

For UI or acquisition changes, validate on real hardware and record:

- hardware model and architecture;
- macOS version;
- active displays;
- GPU model and provider class;
- sampling profile;
- workload sequence;
- expected and observed result.

## Parser contributions

A new key requires:

- a sanitized representative dictionary;
- unit and scale definition;
- range validation;
- conflict precedence relative to existing keys;
- tests;
- documentation in `docs/METRICS.md` or `docs/COMPATIBILITY.md`.

## Style

- prefer native frameworks and small focused types;
- avoid force unwraps in telemetry paths;
- keep acquisition, transformation, persistence, and presentation separate;
- use explicit state instead of magic values;
- document approximations as approximations;
- do not log identifying machine data by default.
