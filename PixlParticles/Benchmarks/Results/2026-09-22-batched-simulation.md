# Batched simulation comparison — 2026-09-22

Measured on Apple M4 Pro (Mac16,8), 10 performance + 4 efficiency cores,
macOS 27.0 (26A428), AC power. Xcode Swift 6.4
(`swiftlang-6.4.0.34.1`, `clang-2100.3.34.1`). Native arm64, `-O`, WMO,
cross-module optimization, Swift 6. No concurrent benchmark runs. The particle
app was closed for the final comparison.

## Workload and method

Production simulation at 60 fixed ticks/s: seed 0, sphere surface radius 100,
lifetime 2 seconds, spawn rate half the listed live count per second, unlimited
duration, no retained rewind state. Each process warms up 150 ticks (including
filling the emitter), then measures 301 whole ticks. Timings include position
integration, scheduling/completion, deterministic spawn generation, lifetime
bookkeeping, recycling, and storage writes. Rendering/GPU/UI are excluded.
Checksums traverse all particles after timing and include IDs, previous/current
positions, and velocities.

The serial executable was built and run **before production edits**, from
repository revision `1b326e30286582b9c05ff6a8c0d38d6aae002e1a`.
Its initial three-run median was **0.520917 ms at 1M** and **1.038167 ms at 2M**.
The exact same preserved executable was rerun in the final comparison below.
A current-source serial check measured 0.545875 / 1.096791 ms at 1M / 2M,
with matching checksums.

Each final round ran preserved serial, all-core-count, then P-core-count, in
that order. Three rounds, sequentially. The table reports the median of three
per-run medians and median of three per-run p95 values, not a pooled p95.

| Particles | Mode | Total workers | Median ms/tick | p95 ms/tick | Median reduction vs serial |
| ---: | --- | ---: | ---: | ---: | ---: |
| 1,000,000 | serial | 1 | 0.546417 | 0.590333 | 0.0% |
| 1,000,000 | all | 14 | 0.244417 | 2.900042 | 55.3% |
| 1,000,000 | performance | 10 | 0.217125 | 0.863666 | 60.3% |
| 2,000,000 | serial | 1 | 1.146333 | 1.500333 | 0.0% |
| 2,000,000 | all | 14 | 0.619416 | 6.017375 | 46.0% |
| 2,000,000 | performance | 10 | 0.468916 | 0.791791 | 59.1% |

Both parallel configurations use four batches per worker: 56 / 40 per pass,
capped by available elements. The submitting thread is one of the workers;
there are 13 / 9 persistent background threads. Position ranges cover whole
four-particle SIMD batches. Every thread uses user-interactive QoS.

`performance` means a pool sized to the performance-core count. macOS owns
actual placement; this is not proof that execution used only P cores.

The 10-worker configuration has the lower median and p95 at 2M in this run.
The all-core-count configuration improves the median but increases p95 versus
serial. No cause is inferred from these timings. The app default remains `all`
as requested for initial experimentation.

Checksums are identical in every configuration and run:

- 1M: `31425887834056999`
- 2M: `62858961691525918`

## Reproduction and switches

From PixlParticles:

```sh
./.scripts/benchmark-simulation serial 4
./.scripts/benchmark-simulation all 4
./.scripts/benchmark-simulation performance 4
```

Run commands sequentially. The optional second argument changes batches per
worker. The harness compiles real particle and renderer sources plus the exact
Apple pool sources from the sibling PixlParticlesUI project; no PixlConcurrency
code is involved. Older System/LiveTick harnesses use the superseded
particle-count initializer; this new harness uses the current spawn/lifetime API.

For Xcode Run environment:

- `PIXL_SIMULATION_CORES`: `all` (default), `performance`, or `serial`.
- `PIXL_SIMULATION_BATCHES`: positive integer up to 1024 (default `4`).

The pool is created once per render worker and reused across ticks and system
replacements. Spawn scratch storage is allocated once per emitter, reused across
ticks/seeks, and recreated after emitter reconfiguration. No per-tick thread
creation, mutex, or condition-variable wait is introduced.

## Validation

- Three focused tests pass under Thread Sanitizer: repeated exact range coverage,
  bit-exact serial/parallel simulation including recycling/removal/seek, and
  changed spawn rate with the same arena capacity.
- Universal macOS app build passes. The app was not launched by the agent.
- WASM parallel performance was not measured: this pool is the Apple UI adapter;
  the installed machine has no WebAssembly snapshot toolchain. The simulation
  job interface remains platform-independent Swift.
- These benchmark results are retained for review here; PERF.md contains only
  accepted baselines.

## Raw final runs

```text
particles=1000000 median_ms=0.546375 p95_ms=0.5765 checksum=31425887834056999
particles=2000000 median_ms=1.146333 p95_ms=1.5003330000000001 checksum=62858961691525918
mode=all workers=14 batches_per_worker=4
particles=1000000 median_ms=0.26491600000000004 p95_ms=3.278084 checksum=31425887834056999
particles=2000000 median_ms=0.6194160000000001 p95_ms=6.017375 checksum=62858961691525918
mode=performance workers=10 batches_per_worker=4
particles=1000000 median_ms=0.293667 p95_ms=2.50775 checksum=31425887834056999
particles=2000000 median_ms=0.501625 p95_ms=3.7371670000000003 checksum=62858961691525918
particles=1000000 median_ms=0.546417 p95_ms=0.596333 checksum=31425887834056999
particles=2000000 median_ms=1.182541 p95_ms=1.58525 checksum=62858961691525918
mode=all workers=14 batches_per_worker=4
particles=1000000 median_ms=0.24441700000000002 p95_ms=2.900042 checksum=31425887834056999
particles=2000000 median_ms=0.592458 p95_ms=5.627000000000001 checksum=62858961691525918
mode=performance workers=10 batches_per_worker=4
particles=1000000 median_ms=0.217125 p95_ms=0.6032080000000001 checksum=31425887834056999
particles=2000000 median_ms=0.46891600000000005 p95_ms=0.791791 checksum=62858961691525918
particles=1000000 median_ms=0.55 p95_ms=0.590333 checksum=31425887834056999
particles=2000000 median_ms=1.1272920000000002 p95_ms=1.1814580000000001 checksum=62858961691525918
mode=all workers=14 batches_per_worker=4
particles=1000000 median_ms=0.227916 p95_ms=1.218666 checksum=31425887834056999
particles=2000000 median_ms=0.668833 p95_ms=8.784041 checksum=62858961691525918
mode=performance workers=10 batches_per_worker=4
particles=1000000 median_ms=0.21416600000000002 p95_ms=0.863666 checksum=31425887834056999
particles=2000000 median_ms=0.46841700000000003 p95_ms=0.6913750000000001 checksum=62858961691525918
```

## Initial pre-edit serial runs

```text
particles=1000000 median_ms=0.510542 p95_ms=0.5300830000000001 checksum=31425887834056999
particles=2000000 median_ms=1.0357500000000002 p95_ms=1.131 checksum=62858961691525918
particles=1000000 median_ms=0.5209170000000001 p95_ms=0.5737500000000001 checksum=31425887834056999
particles=2000000 median_ms=1.038167 p95_ms=1.0675000000000001 checksum=62858961691525918
particles=1000000 median_ms=0.524 p95_ms=0.5341670000000001 checksum=31425887834056999
particles=2000000 median_ms=1.0505410000000002 p95_ms=1.138209 checksum=62858961691525918
```
