# Metrics and Measurement Methodology

## 1. Scope and epistemic status

MacPulse reports operating-system counters and driver-published properties. It does not claim electrical laboratory accuracy, private-framework parity, or equivalence to vendor-specific profilers. Every metric is classified as one of:

- directly measured from a public system counter;
- read from a driver property;
- derived from documented counters;
- unavailable.

No unavailable metric is synthetically replaced.

## 2. CPU utilization

Cumulative Mach ticks are read using `HOST_CPU_LOAD_INFO`.

Let:

- `u_t` = cumulative user ticks;
- `s_t` = cumulative system ticks;
- `n_t` = cumulative nice ticks;
- `i_t` = cumulative idle ticks.

For two samples:

```text
Δbusy  = Δu + Δs + Δn
Δtotal = Δu + Δs + Δn + Δi
CPU%   = 100 × Δbusy / Δtotal
```

The first read establishes a baseline. User and system components are retained separately. Results are clamped to `[0,100]` to contain malformed or discontinuous intervals.

Load averages are operating-system queue measures and are displayed without conversion to percentages.

## 3. Memory

Total memory comes from `ProcessInfo.physicalMemory`. Mach VM statistics provide free, speculative, inactive, purgeable, wired, and compressed pages.

MacPulse estimates reclaimable memory as:

```text
reclaimable = free + speculative + inactive + purgeable
used        = physical total − reclaimable
```

The displayed pressure percentage is a documented proxy based on constrained memory:

```text
pressure proxy = 100 × (wired + compressed) / physical total
```

It is not claimed to reproduce Activity Monitor's private memory-pressure algorithm.

## 4. GPU activity

### 4.1 Sources

- Apple Silicon: `AGXAccelerator`
- Intel/AMD and compatible accelerated systems: `IOAccelerator`
- fallback: XML property-list output from `/usr/sbin/ioreg`

`IORegistryEntryCreateCFProperties` returns an instantaneous snapshot of an entry's property table. The driver defines the properties and can change them across hardware and macOS releases.

### 4.2 Percentage normalization

Values in `[0,1]` are interpreted as fractions and multiplied by 100. Values already in percentage-point form are clamped directly to `[0,100]`.

### 4.3 Optional fields

Temperature is accepted only in the plausible interval `[-20,150] °C`. Negative clocks, memory values, power, and fan speeds are rejected. Non-finite values are rejected.

MacPulse does not derive physical VRAM total from `inUseVidMemoryBytes + vramFreeBytes`, because allocation and reusable-cache counters may exceed physical memory or describe different address domains.

### 4.4 Reclaimable GPU memory

Some AMD drivers expose `orphanedReusableVidMemoryBytes`. MacPulse labels this as reclaimable cache rather than active application memory. This distinction is important when apparent in-use allocations approach or exceed nominal VRAM.

## 5. Smoothing

The visual model uses:

```text
α = 1 − exp(−Δt / τ)
y_t = y_(t−1) + α(x_t − y_(t−1))
```

Two constants are used:

- attack time `τ_a` when `x_t ≥ y_(t−1)`;
- release time `τ_r` when `x_t < y_(t−1)`.

Calm mode uses `τ_a < τ_r`. A rate limiter then constrains maximum rise and fall in percentage points per second. Raw values remain separately available.

## 6. Sampling bias

A sampled monitor can miss events shorter than its interval. Adaptive backoff increases this probability during idle/background periods by design. Opening the dashboard reduces the interval. MacPulse is appropriate for ambient observation, not microbenchmark instrumentation.

## 7. Staleness

A missing GPU dictionary is not equivalent to a measured zero. A prior valid value may be held for at most a short timeout and marked stale. After timeout, utilization becomes unavailable.

## 8. Validation protocol

Recommended validation uses:

1. Activity Monitor GPU History;
2. a controlled Metal workload;
3. idle, moderate, and saturated phases;
4. sleep/wake;
5. integrated/discrete switching where available;
6. Low Power Mode;
7. repeated IORegistry capture.

Compare trends and transitions, not assumed equality with private tools.
