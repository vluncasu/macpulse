# Shared Data Model

The app and widget exchange a versioned `SharedPayload` encoded as JSON with millisecond timestamps.

## Envelope

```text
SharedPayload
├── schemaVersion
├── snapshot
└── history[]
```

The current schema is version 2. A decoder rejects payloads with another schema number instead of partially interpreting an incompatible structure.

## Snapshot semantics

`SystemSnapshot` is one coherent observation with:

- acquisition timestamp and monotonic sequence number;
- CPU, primary GPU, all detected GPUs, and memory snapshots;
- machine classification;
- thermal and Low Power state;
- effective main-loop interval;
- current monitoring-session uptime.

The timestamp identifies acquisition, not widget rendering time.

## History

`MetricHistoryPoint` contains timestamped CPU, optional GPU, and memory percentages. Runtime history follows the selected one-, three-, or ten-minute window. Shared history is downsampled to at most 180 points to bound file size and widget decode work.

## Persistence

The application writes an atomic JSON file to its local Application Support directory. A standard-defaults data blob is a secondary fallback. The widget independently creates a `SharedPayload` during timeline generation and retains a bounded history inside its own sandbox.

Atomic replacement prevents the widget from observing a partially written JSON document. The widget retains no database and makes no network request.

## Compatibility rules

- Additive optional fields may be introduced within a schema only when older decoders can ignore them.
- Renamed, removed, or semantically changed fields require a schema increment.
- A schema migration must be deterministic and tested.
- Unknown freshness or provider states must decode safely or invalidate the payload.
- Byte values remain bytes in the data model; human-readable unit conversion belongs to the view layer.
