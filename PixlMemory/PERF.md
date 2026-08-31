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
cross-module optimisation enabled. Each result uses 5 warmups and 31 measured
samples. Benchmarks run sequentially.

| Benchmark | Unit | Median | p95 | Max |
| --- | --- | ---: | ---: | ---: |
| Arena construction | arena | 1.43 µs | 1.45 µs | 1.49 µs |
| Scope acquire/release | scope | 518.41 ns | 537.46 ns | 555.94 ns |
| Indexed append | element | 70.03 ns | 76.14 ns | 76.80 ns |
| Indexed bulk append | element | 0.57 ns | 0.58 ns | 0.61 ns |
| Indexed mutable iteration | element | 0.18 ns | 0.20 ns | 0.20 ns |
| Raw append, 64 bytes | chunk | 87.73 ns | 96.29 ns | 105.74 ns |
| Raw mutable iteration | byte | 0.08 ns | 0.08 ns | 0.09 ns |
| Dense-pool insert | element | 91.60 ns | 94.10 ns | 94.50 ns |
| Dense-pool remove | element | 86.14 ns | 88.53 ns | 90.54 ns |
| Dense-pool handle lookup | lookup | 5.66 ns | 6.12 ns | 6.59 ns |
| Dense-pool iteration | element | 0.13 ns | 0.13 ns | 0.15 ns |
| Mixed frame, small | frame | 33.17 µs | 39.29 µs | 43.67 µs |
| Mixed frame, heavy | frame | 278.17 µs | 293.58 µs | 325.00 µs |
| Particle integration, 2 M | particle | 0.51 ns | 0.53 ns | 0.55 ns |
| Particle integration, 2 M | frame | 1.02 ms | 1.06 ms | 1.09 ms |

The small mixed frame integrates 10,000 actors, rebuilds 10,000 render
positions from that state, churns 100 dense-pool entries, performs 1,000 handle
lookups, and fills 64 KB of scratch storage. The heavy frame integrates 100,000
actors, rebuilds 100,000 render positions, churns 1,000 entries, performs 1,000
lookups, and fills 1 MB of scratch storage.

Mixed-frame values measure PixlMemory and representative data work only. They
are not complete game-frame or renderer timings.

Across three sequential process runs, mixed-frame medians ranged from
32.13–33.67 µs for the small workload and 277.63–284.29 µs for the heavy
workload.

Raw iteration validates an exact checksum covering every mutated byte and
checks every final byte after measurement. Optimised arm64 output uses SIMD
loads, additions, stores, and a scalar tail; the result is real vectorised,
cache-resident throughput rather than eliminated work.

### Particle-like integration

The 2-million-particle workload uses 500,000 four-particle batches. Each batch
contains three `SIMD4<Float>` components. Current position, previous position,
and velocity use separate buffers; each pass writes the next position from the
current position and velocity, then swaps position-buffer roles. This reserves
approximately 72 MB and streams at least 72 MB per integration pass.

Three sequential runs measured 1.02–1.03 ms median and 1.06–1.07 ms p95. The
representative 1.02 ms median is approximately 6.1% of a 16.67 ms frame and
implies roughly 70 GB/s of effective buffer traffic. At 60 integrations per
second, the pass alone represents about 4.32 GB/s of sustained traffic.

Validation checks every lane in both final position buffers against the
expected result after all warmup and measured passes. This benchmark covers
only fixed-delta position integration over PixlMemory storage. It excludes
particle lifetime management, spawning, properties, culling, rendering, GPU
work, and application memory.
