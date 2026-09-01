# PixlMemory Performance Baselines

These measurements are specific to the standalone PixlMemory package and its
Sandbox executable. Compare future results using the same build configuration
and similar runtime conditions.

## Sandbox CLI — Release Baseline

Recorded on 2026-08-31 before PixlMemory performs payload backing allocations.
The Sandbox constructs tracking metadata, representative memory plans, and an
arena, then waits in its command loop. It does not allocate any planned payload
memory.

| Measurement | Resident memory |
| --- | ---: |
| Observed release range | 3.60–3.80 MB |

This is the standalone CLI/process baseline, not PixlMemory-managed capacity.
Use it to detect process-memory changes as backing allocation and storage are
introduced. Exact hardware, operating-system build, sampling tool, and sample
count were not recorded for this initial observation.

An arena containing an empty layout was subsequently observed at the same
3.80 MB release baseline. Registering a layout with no reservations therefore
added no observable resident memory in Xcode's memory gauge.

## Host Release Benchmarks

Accepted on 2026-08-31 using an Apple M4 Pro MacBook Pro (14 cores, 48 GB),
macOS 27.0 (26A5421a), and Apple Swift 6.4. Built with `-O` and PixlMemory
cross-module optimisation enabled. Each process run uses 5 warmups and 31
measured samples. Benchmarks run sequentially. The table reports the median of
each column across three sequential process runs. The MacBook was connected to
power for these accepted runs. Future comparisons must use external power and
confirm that Low Power Mode is disabled; battery or Low Power Mode results are
not directly comparable.

| Benchmark | Unit | Median | p95 | Max |
| --- | --- | ---: | ---: | ---: |
| Arena construction | arena | 916.65 ns | 934.57 ns | 948.40 ns |
| Scope acquire/release | scope | 338.42 ns | 346.79 ns | 366.56 ns |
| Indexed append | element | 46.65 ns | 49.23 ns | 50.08 ns |
| Indexed bulk append | element | 0.30 ns | 0.32 ns | 0.37 ns |
| Indexed mutable iteration | element | 0.12 ns | 0.14 ns | 0.15 ns |
| Paired fixed append | element | 47.23 ns | 48.48 ns | 48.78 ns |
| Growing retained append | element | 47.96 ns | 49.12 ns | 49.84 ns |
| Growth 1K → 2K | growth | 334.00 ns | 375.00 ns | 417.00 ns |
| Growth 16K → 32K | growth | 2.13 µs | 2.25 µs | 2.67 µs |
| Growth 128K → 256K | growth | 16.83 µs | 17.04 µs | 20.33 µs |
| Growth 1M → 2M | growth | 111.04 µs | 115.08 µs | 121.46 µs |
| Growing cold append | element | 47.91 ns | 49.47 ns | 51.01 ns |
| Growing cold bulk append | element | 0.38 ns | 0.40 ns | 0.41 ns |
| Growing mutable iteration | element | 0.12 ns | 0.12 ns | 0.12 ns |
| Raw append, 64 bytes | chunk | 55.36 ns | 58.74 ns | 59.60 ns |
| Raw mutable iteration | byte | 0.05 ns | 0.05 ns | 0.07 ns |
| Dense-pool insert | element | 57.56 ns | 59.46 ns | 59.98 ns |
| Dense-pool remove | element | 54.63 ns | 56.21 ns | 56.95 ns |
| Dense-pool handle lookup | lookup | 3.62 ns | 3.81 ns | 3.90 ns |
| Dense-pool iteration | element | 0.08 ns | 0.11 ns | 0.14 ns |
| Mixed frame, small | frame | 20.96 µs | 25.17 µs | 28.17 µs |
| Mixed frame, heavy | frame | 175.83 µs | 195.38 µs | 204.33 µs |
| Particle integration, 2 M | particle | 0.32 ns | 0.35 ns | 0.39 ns |
| Particle integration, 2 M | frame | 634.96 µs | 695.88 µs | 773.33 µs |

The small mixed frame integrates 10,000 actors, rebuilds 10,000 render
positions from that state, churns 100 dense-pool entries, performs 1,000 handle
lookups, and fills 64 KB of scratch storage. The heavy frame integrates 100,000
actors, rebuilds 100,000 render positions, churns 1,000 entries, performs 1,000
lookups, and fills 1 MB of scratch storage.

Mixed-frame values measure PixlMemory and representative data work only. They
are not complete game-frame or renderer timings.

Across three sequential process runs, mixed-frame medians ranged from
20.92–21.75 µs for the small workload and 173.42–186.29 µs for the heavy
workload.

Raw iteration validates an exact checksum covering every mutated byte and
checks every final byte after measurement. Optimised arm64 output uses SIMD
loads, additions, stores, and a scalar tail; the result is real vectorised,
cache-resident throughput rather than eliminated work.

### Automatically growing indexed buffers

Accepted on 2026-09-01 under the same host, release, sequential-run, and
external-power conditions. The growing buffer starts with capacity for 1,024
`UInt64` values and doubles while filling 250,000 values, reaching a retained
capacity of 262,144 values (2.10 MB). “Cold append” includes every allocation,
copy, and release needed to reach that capacity. “Cold bulk append” supplies
the complete count upfront and therefore performs one allocation. “Retained”
reuses the established capacity without further allocation.

Across the same three runs, the existing fixed indexed-buffer append measured
46.69–46.95 ns per element, bulk append measured 0.30–0.37 ns, and mutable
iteration measured 0.11–0.12 ns. A separate alternating comparison gave equal
262,144-element capacities to fixed and stabilized-growing buffers and reversed
their execution order between samples. The expanded final harness measured
47.23 versus 47.96 ns per append; an earlier independent three-run paired
sequence measured 46.11 versus 46.21 ns. Growing mutable iteration was identical
to fixed iteration in both. Growth is policy metadata and is consulted only
when capacity is exhausted; subsequent appends and contiguous traversal retain
fixed-buffer hot-path characteristics.

The explicit growth rows time only the append that crosses capacity; preparation
fills the old allocation before timing. Because elements are `UInt64`, the four
rows copy 8.19 KB, 131.07 KB, 1.05 MB, and 8.39 MB respectively into allocations
twice that size. The next append immediately returns to the retained hot path.
Actual growth cost scales primarily with copied bytes, so element counts alone
must not be used to predict costs for larger record types.

### Particle-like integration

The 2-million-particle workload uses 500,000 four-particle batches. Each batch
contains three `SIMD4<Float>` components. Current position, previous position,
and velocity use separate buffers; each pass writes the next position from the
current position and velocity, then swaps position-buffer roles. This reserves
approximately 72 MB and streams at least 72 MB per integration pass.

Three sequential runs measured 611.54–635.33 µs median and 639.50–723.00 µs
p95. The aggregate 634.96 µs median is approximately 3.8% of a 16.67 ms frame
and implies roughly 113 GB/s of effective buffer traffic. At 60 integrations
per second, the pass alone represents about 4.32 GB/s of sustained traffic.

Validation checks every lane in both final position buffers against the
expected result after all warmup and measured passes. This benchmark covers
only fixed-delta position integration over PixlMemory storage. It excludes
particle lifetime management, spawning, properties, culling, rendering, GPU
work, and application memory.
