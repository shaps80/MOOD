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
| Box volume | 40.74 M particles/s · 24.55 ns/particle | 69.91 M particles/s · 14.30 ns/particle | 32.28 M particles/s · 30.98 ns/particle | `1246931346963` |
| Box surface | 23.61 M particles/s · 42.36 ns/particle | 37.43 M particles/s · 26.72 ns/particle | 20.97 M particles/s · 47.69 ns/particle | `1231086806959` |
| Sphere volume | 16.63 M particles/s · 60.12 ns/particle | 28.85 M particles/s · 34.66 ns/particle | 12.32 M particles/s · 81.18 ns/particle | `1228237922277` |
| Sphere surface | 25.81 M particles/s · 38.74 ns/particle | 47.88 M particles/s · 20.88 ns/particle | 20.70 M particles/s · 48.30 ns/particle | `1242808241845` |

The matching checksums confirm that each platform produced identical sampled
particle state. Sphere volume is slower because rejection sampling sometimes
needs more than one candidate; sphere surface is effectively level with box
surface on WebAssembly.

### AoSoA production storage

Measured after lowering production particle state into unsafe four-particle
AoSoA batches. The initial rewind state stores positions only rather than copying
identifiers, previous positions, and immutable velocities.

| Region | macOS M1 Max | Checksum |
| --- | ---: | ---: |
| Point | 53.30 M particles/s · 18.76 ns/particle | `425986654175` |
| Line | 46.71 M particles/s · 21.41 ns/particle | `688322051651` |
| Box volume | 37.96 M particles/s · 26.34 ns/particle | `1246931346963` |
| Box surface | 23.67 M particles/s · 42.24 ns/particle | `1231086806959` |
| Sphere volume | 16.73 M particles/s · 59.77 ns/particle | `1228237922277` |
| Sphere surface | 24.72 M particles/s · 40.45 ns/particle | `1242808241845` |

Cheap regions expose the cost of packing and eagerly retaining rewind state;
regions dominated by sampling math remain close to the earlier baseline. The
position-only rewind snapshot costs approximately 12 bytes per particle rather
than the earlier full AoSoA snapshot's 44 bytes per particle. iPad and
WebAssembly initialization must be remeasured for the new production layout.

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

The immediately preceding production implementation measured 840.66 million
updates/s and 1.190 ms per million-particle tick in the same session. AoSoA
therefore increased throughput by approximately 86% and reduced tick time by
approximately 46%, with identical output. This benchmark remains
single-threaded and excludes scheduling, snapshot materialization,
interpolation, and rendering.

| Platform | 30 Hz | 60 Hz | 120 Hz |
| --- | ---: | ---: | ---: |
| macOS M1 Max AoSoA | 52.00 M | 26.00 M | 13.00 M |

iPad and WebAssembly fixed updates must be remeasured against the production
AoSoA implementation before replacing their earlier baselines.
