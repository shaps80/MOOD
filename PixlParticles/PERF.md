# PixlParticles Performance

Record accepted, reproducible performance baselines here. Compare results only
when the benchmark workload, build configuration, toolchain, and runtime match.

## Deterministic Random Generation

Measured 2026-08-15 on an Apple M1 Max Mac Studio with 64 GB memory, running
macOS 27.0 (26A5406e).

The standalone `Benchmarks/Random/RandomBenchmarks.swift` harness compiles with
the real production sources. Each path warms up with 1 million Philox blocks,
then reports the median of five runs containing 10 million blocks each. Every
block produces four words or mapped floats, so each measured run produces 40
million values. The benchmark driver disables its own optimisation to prevent
hoisting; the measured production paths compile with `-O` and whole-module
optimisation.

| Path | macOS M1 Max | iPad M5 | WebAssembly | Checksum |
| --- | ---: | ---: | ---: | ---: |
| Philox raw words | 488.77 million values/s | 819.89 million values/s | 445.75 million values/s | `85900635147323622` |
| Half-open ranged floats | 466.58 million values/s | 755.31 million values/s | 384.30 million values/s | `87285233708789853` |
| Closed ranged floats | 402.50 million values/s | 666.01 million values/s | 341.74 million values/s | `87285234823698366` |

The matching checksums confirm that these benchmark workloads produced the same
raw words and mapped `Float` bit patterns through both execution paths.

### Environments

- macOS: M1 Max Mac Studio, Apple Swift 6.4 (`swiftlang-6.4.0.30.4`, `clang-2100.3.30.1`), native arm64 executable.
- iPadOS: iPad Pro 11-inch (M5), iPad17,1, 10-core arm64e, iPadOS 27.0 (24A5408d), wired; Xcode 27.0 (27A5237l), Apple Swift 6.4 (`swiftlang-6.4.0.30.4`), deployment target iOS 17.0.
- WebAssembly: Swift 6.4 development snapshot 2026-07-17, `wasm32-unknown-wasip1`, executed by Node.js 24.1.0's WASI runtime on the same machine.

WebAssembly baselines must be compiled directly with `swiftc -O
-whole-module-optimization`, without `-num-threads`. With this toolchain,
SwiftPM adds `-num-threads` even for release WMO builds; its presence partitions
code generation and reduces cross-file Philox throughput from roughly 447 to 12
million values/s. This is a benchmark-build regression, not production evidence.

SIMD-enabled WebAssembly builds must also pass `-Xcc -msimd128`. Without it,
Swift's `SIMD4` operations were scalarized and the inspected benchmark binary
contained no WebAssembly SIMD instructions. With it, the binary emitted `v128`
operations and retained matching deterministic checksums.

### Earlier provisional comparison

Before the retained harness existed, a temporary 100-million-block microbenchmark
measured roughly 436 million Swift Philox words/s and 411 million words/s for the
canonical Random123 C++ implementation. Treat those figures as directional only;
the exact harness was not retained, so the table above is the reproducible baseline.

## System Initialization

Measured 2026-08-16 using the environments above. The standalone
`Benchmarks/System/SystemBenchmarks.swift` harness compiles with the real
production sources using `-O` and whole-module optimization.

Each region warms up by creating 100,000 particles, then reports the median of
five complete `System` initializations containing 1 million particles each. The
timed work includes particle allocation, identifiers, deterministic position
sampling, and deterministic velocity generation. An optimized checksum over 64
representative particles runs outside the timed interval to retain observable
output without contaminating the measurement.

| Region | macOS M1 Max | iPad M5 | WebAssembly | Checksum |
| --- | ---: | ---: | ---: | ---: |
| Point | 68.23 M particles/s · 14.66 ns/particle | 99.40 M particles/s · 10.06 ns/particle | 45.54 M particles/s · 21.96 ns/particle | `425986654175` |
| Line | 54.22 M particles/s · 18.44 ns/particle | 91.26 M particles/s · 10.96 ns/particle | 44.28 M particles/s · 22.58 ns/particle | `688322051651` |
| Cube volume | 40.74 M particles/s · 24.55 ns/particle | 69.91 M particles/s · 14.30 ns/particle | 32.28 M particles/s · 30.98 ns/particle | `1246931346963` |
| Cube surface | 23.61 M particles/s · 42.36 ns/particle | 37.43 M particles/s · 26.72 ns/particle | 20.97 M particles/s · 47.69 ns/particle | `1231086806959` |
| Sphere volume | 16.63 M particles/s · 60.12 ns/particle | 28.85 M particles/s · 34.66 ns/particle | 12.32 M particles/s · 81.18 ns/particle | `1228237922277` |
| Sphere surface | 25.81 M particles/s · 38.74 ns/particle | 47.88 M particles/s · 20.88 ns/particle | 20.70 M particles/s · 48.30 ns/particle | `1242808241845` |

The matching checksums confirm that each platform produced identical sampled
particle state. Sphere volume is slower because rejection sampling sometimes
needs more than one candidate; sphere surface is effectively level with cube
surface on WebAssembly.

### AoSoA production storage

Measured after lowering production particle state into unsafe four-particle
AoSoA batches. The initial rewind state stores positions only rather than copying
identifiers, previous positions, and immutable velocities.

| Region | macOS M1 Max | WebAssembly | Checksum |
| --- | ---: | ---: | ---: |
| Point | 53.30 M particles/s · 18.76 ns/particle | 42.65 M particles/s · 23.45 ns/particle | `425986654175` |
| Line | 46.71 M particles/s · 21.41 ns/particle | 38.39 M particles/s · 26.05 ns/particle | `688322051651` |
| Cube volume | 37.96 M particles/s · 26.34 ns/particle | 30.13 M particles/s · 33.19 ns/particle | `1246931346963` |
| Cube surface | 23.67 M particles/s · 42.24 ns/particle | 20.11 M particles/s · 49.72 ns/particle | `1231086806959` |
| Sphere volume | 16.73 M particles/s · 59.77 ns/particle | 11.27 M particles/s · 88.73 ns/particle | `1228237922277` |
| Sphere surface | 24.72 M particles/s · 40.45 ns/particle | 18.79 M particles/s · 53.21 ns/particle | `1242808241845` |

Cheap regions expose the cost of packing and eagerly retaining rewind state;
regions dominated by sampling math remain close to the earlier baseline. The
position-only rewind snapshot costs approximately 12 bytes per particle rather
than the earlier full AoSoA snapshot's 44 bytes per particle. iPad
initialization must still be remeasured for the new production layout.

## Fixed Simulation Updates

The fixed-update benchmark creates 1 million point-spawned particles, performs
10 warm-up ticks, then reports the median of five samples containing 100 ticks
each. It calls the production linear-motion update loop directly, excluding loop
scheduling, sampling, interpolation, and rendering.

| Platform | Throughput | Cost per update | 1 M-particle tick |
| --- | ---: | ---: | ---: |
| macOS M1 Max | 809.91 M updates/s | 1.23 ns | 1.23 ms |
| iPad M5 | 929.55 M updates/s | 1.08 ns | 1.08 ms |
| WebAssembly | 530.76 M updates/s | 1.88 ns | 1.88 ms |

All platforms produced checksum `1295003598899`.

Theoretical particle ceilings below divide measured throughput by tick rate and
assume perfect scaling with no renderer or other simulation work:

| Platform | 30 Hz | 60 Hz | 120 Hz |
| --- | ---: | ---: | ---: |
| macOS M1 Max | 27.00 M | 13.50 M | 6.75 M |
| iPad M5 | 30.99 M | 15.49 M | 7.75 M |
| WebAssembly | 17.69 M | 8.85 M | 4.42 M |

### AoSoA SIMD baseline

The production CPU update now stores each three-component property as batches
of three `SIMD4<Float>` values, with each SIMD lane representing one particle.
Property buffers remain separate. This avoids `SIMD3` padding while updating
four particles per operation.

| Platform | Throughput | Cost per update | 1 M-particle tick | Checksum |
| --- | ---: | ---: | ---: | ---: |
| macOS M1 Max | 1,559.86 M updates/s | 0.641 ns | 0.641 ms | `1295003598899` |
| WebAssembly | 1,612.97 M updates/s | 0.620 ns | 0.620 ms | `1295003598899` |

The immediately preceding production implementation measured 840.66 million
updates/s and 1.190 ms per million-particle tick in the same session. AoSoA
therefore increased throughput by approximately 86% and reduced tick time by
approximately 46%, with identical output. This benchmark remains
single-threaded and excludes scheduling, snapshot materialization,
interpolation, and rendering.

The WebAssembly result used direct WMO compilation with `-Xcc -msimd128`; the
inspected binary contained 331 SIMD opcode lines. It improved from the earlier
530.76 million updates/s and 1.88 ms baseline to 1,612.97 million updates/s and
0.620 ms. Node/V8 therefore measured marginally faster than native Swift for
this focused loop on the same M1 Max hardware; this is not a general comparison
between WebAssembly and native execution.

| Platform | 30 Hz | 60 Hz | 120 Hz |
| --- | ---: | ---: | ---: |
| macOS M1 Max AoSoA | 52.00 M | 26.00 M | 13.00 M |
| WebAssembly AoSoA | 53.77 M | 26.88 M | 13.44 M |

iPad fixed updates must be remeasured against the production AoSoA
implementation before replacing its earlier baseline.

## Renderer Buffer Access

Measured 2026-08-16 on the macOS and WebAssembly environments above. The
standalone `Benchmarks/Renderer/BufferAccessBenchmarks.swift` harness compiles
with the production `Vector3Batch` and packed `Position` types. It compares the
same SIMD interpolation and packed-position writes through borrowed `Span`
sources and `UnsafeBufferPointer` sources.

The harness warms both paths with 10 one-million-particle passes, then
alternates their measurement order. Each reported result is the median of five
samples containing 100 one-million-particle passes. Runs are sequential.

| Source view | macOS M1 Max | WebAssembly | Checksum |
| --- | ---: | ---: | ---: |
| `Span` | 1,764.12 M particles/s · 0.567 ns/particle | 236.51 M particles/s · 4.228 ns/particle | `233860995248` |
| `UnsafeBufferPointer` | 1,777.24 M particles/s · 0.563 ns/particle | 236.11 M particles/s · 4.235 ns/particle | `233860995248` |

The native difference was approximately 0.7% in favour of unsafe buffers; the
WebAssembly difference was approximately 0.2% in favour of `Span`. Repeated
native runs changed which path led. Treat the paths as equivalent for this
workload and prefer non-escapable `Span` for borrowed read access.

The production `PixlParticles` and `PixlRenderer` modules also compile
successfully for `wasm32-unknown-wasip1` with the accepted direct Swift 6.4
snapshot invocation, whole-module optimization, no `-num-threads`, and
`-Xcc -msimd128`.

## CPU-Interpolated Position Lowering (Superseded)

Measured 2026-08-16 on the macOS M1 Max environment above. The standalone
`Benchmarks/Renderer/LoweringBenchmarks.swift` harness compiles the production
`PixlParticles` and `PixlRenderer` sources with `-O`, whole-module optimization,
and cross-module optimization. It calls the real `Renderer.lowerPositions`
path, including `System.withPositions`, SIMD interpolation, and packed writes.
It excludes simulation and Metal submission.

The harness warms up with 10 one-million-particle passes, then reports the
median of five samples containing 100 passes each. Three complete sequential
runs measured 0.800, 0.785, and 0.798 ms per million particles.

| Platform | Throughput | Cost per particle | 1 M-particle frame | Checksum |
| --- | ---: | ---: | ---: | ---: |
| macOS M1 Max | 1,253.02 M particles/s | 0.798 ns | 0.798 ms | `401125634051` |

This production result must replace the earlier buffer-access microbenchmark
when budgeting renderer CPU time. That microbenchmark remains useful only for
comparing `Span` against unsafe borrowed views under otherwise identical work.

### Simulation regression check

The current production sources measured 1,558.11 million fixed updates/s,
0.642 ns/update, and 0.642 ms per one-million-particle tick with checksum
`1295003598899`. The accepted AoSoA baseline is 1,559.86 million updates/s and
0.641 ms per tick. The 0.1% throughput difference is normal measurement noise;
no simulation regression was detected.

## GPU-Interpolated Position-Pair Lowering

Measured 2026-08-16 on the same macOS M1 Max environment after moving visual
interpolation into the point vertex shader. Production lowering now packs one
24-byte `{ previous, current }` pair per particle only when the simulation tick
changes. The active packed state is reused by intervening render frames; only
the interpolation scalar changes at render frequency.

The retained production harness uses the same warm-up and sampling shape as the
superseded CPU-interpolated baseline. Three complete sequential runs measured
0.768, 0.763, and 0.819 ms per million particles.

| Platform | Throughput | Cost per particle | 1 M-particle tick | Checksum |
| --- | ---: | ---: | ---: | ---: |
| macOS M1 Max | 1,302.50 M particles/s | 0.768 ns | 0.768 ms | `802251268102` |

At a 30 Hz simulation and 60 Hz renderer, lowering therefore averages roughly
0.384 ms per rendered frame per million particles, versus 0.798 ms when CPU
interpolation and packing ran every render frame. The change approximately
halves average lowering CPU time while retaining 60 Hz visual interpolation.
It increases the two renderer state buffers from 24 to 48 bytes per particle in
total and doubles GPU position reads per vertex from 12 to 24 bytes.

### Particle-count scaling

Measured 2026-08-16 on the same macOS M1 Max environment. Each retained
release harness processed at least 100 million particle operations per sample.
The table reports the median result across three complete sequential runs.
Simulation is the production linear-motion pass; lowering is the production
`PixlRenderer` position-pair path. Metal, SwiftUI, editor diagnostics, command
submission, and drawing are excluded.

| Particles | Simulation tick | Position-pair lowering | Combined per 30 Hz tick | Amortized per 60 Hz frame |
| ---: | ---: | ---: | ---: | ---: |
| 10 K | 0.006 ms | 0.006 ms | 0.013 ms | 0.006 ms |
| 50 K | 0.032 ms | 0.031 ms | 0.062 ms | 0.031 ms |
| 100 K | 0.063 ms | 0.063 ms | 0.126 ms | 0.063 ms |
| 250 K | 0.165 ms | 0.180 ms | 0.345 ms | 0.173 ms |
| 500 K | 0.336 ms | 0.381 ms | 0.717 ms | 0.358 ms |
| 1 M | 0.643 ms | 0.780 ms | 1.423 ms | 0.712 ms |
| 2 M | 1.292 ms | 1.633 ms | 2.925 ms | 1.462 ms |

Simulation remained close to linear through 2 million particles. Lowering
throughput decreased after roughly 100,000 particles, consistent with a cache
or memory-bandwidth boundary, but remained inexpensive relative to a 16.67 ms
frame budget. These measurements do not justify CPU multithreading for the
current linear pass. Re-evaluate per pass when collisions, forces, or events
add materially more work; do not select concurrency from particle count alone.

### Renderer-optimization regression check

Measured after making renderer isolation explicit, reducing high-density LOD
storage, and replacing serial GPU scans. Three sequential native runs retained
the same CPU checksums. The median one-million-particle simulation tick was
0.642 ms against the accepted 0.643 ms scaling result. At two million it was
1.285 ms against 1.292 ms. Position-pair lowering measured 0.778 ms at one
million against 0.780 ms, and 1.547 ms at two million against 1.633 ms. No CPU
regression was detected; the two-million lowering improvement is approximately
5.3% in this session. GPU results require a matched post-change Metal trace.

## Metal Point Rendering

Measured 2026-08-16 on the macOS M1 Max environment using Release builds and
Metal System Trace. CPU simulation and portable lowering are measured
separately above. GPU phase intervals may overlap, so vertex and fragment
durations must not be summed.

| Workload | Actual submission rate | GPU frame median | GPU frame p95 | Culling median | Vertex median | Fragment median |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 M | 59.2 FPS | 5.28 ms | 6.01 ms | 0.76 ms | 2.36 ms | 1.63 ms |
| 2 M, early drawable acquisition | 49.5 FPS | 10.00 ms | 12.42 ms | 1.38 ms | 3.92 ms | 3.87 ms |
| 2 M, late drawable acquisition | 59.0 FPS | 11.48 ms | 13.66 ms | 1.32 ms | 1.60 ms | 4.33 ms |

Moving MTKView drawable and render-pass acquisition after buffer availability,
position-pair lowering, and culling encoding reduced median drawable wait from
8.12 to 4.12 ms and restored approximately 60 FPS at 2 million particles. It
required no additional buffering or memory.

A 3-million-particle transition trace showed the next limit. As screen coverage
increased, culling remained near 1.9 ms while fragment time rose from 4.88 to
6.70 ms. Median GPU frame time rose from 13.04 to 15.29 ms and p95 rose from
15.76 to 18.87 ms, crossing the 16.67 ms deadline and producing roughly 30–44
FPS. This evidence justifies screen-space density LOD; further frustum-culling
optimization alone will not recover the lost frame rate.

The pre-optimization 6-million-particle LOD trace, capped at 2 million visible
points, settled at a 33.34 ms submission interval: the 30 Hz display tier.
Aggregate compute measured 13.10 ms median and 16.80 ms p95; point drawing
measured approximately 5.35 ms median and 7.56 ms p95. Metal allocation settled
at 639.08 MiB and peaked at 669.80 MiB while resizing. This is the comparison
baseline for parallel scans, cached tile indices, precomputed thresholds, and
reduced LOD storage.

The matched post-optimization Release trace used the same 6 million simulated
particles, LOD activation at 500,000, a 2-million visible ceiling, 16-pixel
tiles, and one point per pixel on the M1 Max Mac Studio. Across 748 steady-state
frames it measured a 16.647 ms median submission interval and 18.869 ms p95,
approximately 60.1 submissions per second. Aggregate compute measured 3.455 ms
median and 4.244 ms p95; scene drawing measured 2.679 ms median and 5.100 ms
p95; effective GPU work measured 5.958 ms median and 8.550 ms p95. Frames that
blocked for a drawable waited 7.923 ms median and 8.897 ms p95, acting as frame
pacing rather than limiting submission cadence. Metal allocation settled at
557.34 MiB; the capture began after allocation and therefore provides no
separate resize peak.

Against the pre-optimization trace, median compute fell 73.6%, median drawing
fell 49.9%, the display tier recovered from 30 Hz to 60 Hz, and steady Metal
allocation fell 81.74 MiB (12.8%).

After those changes, manual Release-app observation at 6 million particles and
a 2-million visible ceiling measured approximately 960 MiB to 1.0 GiB process
memory, down from approximately 1.18 GiB before the changes. Treat this as an
observed range pending a matched post-change Metal allocation trace.

### Retained-position compaction experiment

Matched 10.77-second traces compared retained 32-bit indices against compacted
clip-space `float4` positions at 6 million simulated particles and a 2-million
visible ceiling. Shader Timeline reduced both captures to approximately 30
submissions per second, but the matched stage comparison remained conclusive.

| Output | Compute median | Effective GPU median | Effective GPU p95 | Metal memory |
| --- | ---: | ---: | ---: | ---: |
| Indices | 3.043 ms | 8.690 ms | 11.657 ms | 561.45 MiB |
| Positions | 3.367 ms | 9.064 ms | 12.838 ms | 607.23 MiB |

Position compaction added 0.324 ms median compute time, increased effective GPU
work by 0.374 ms median and 1.181 ms at p95, and consumed another 45.78 MiB.
The small vertex reduction did not repay the compute write. The experiment was
rejected and removed; indexed LOD remains the production path.
