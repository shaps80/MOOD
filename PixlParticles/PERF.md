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

| Path | macOS arm64 | WebAssembly | Checksum |
| --- | ---: | ---: | ---: |
| Philox raw words | 488.77 million values/s | 445.75 million values/s | `85900635147323622` |
| Half-open ranged floats | 466.58 million values/s | 384.30 million values/s | `87285233708789853` |
| Closed ranged floats | 402.50 million values/s | 341.74 million values/s | `87285234823698366` |

The matching checksums confirm that these benchmark workloads produced the same
raw words and mapped `Float` bit patterns through both execution paths.

### Environments

- macOS: Apple Swift 6.4 (`swiftlang-6.4.0.30.4`, `clang-2100.3.30.1`), native arm64 executable.
- WebAssembly: Swift 6.4 development snapshot 2026-07-17, `wasm32-unknown-wasip1`, executed by Node.js 24.1.0's WASI runtime on the same machine.

### Earlier provisional comparison

Before the retained harness existed, a temporary 100-million-block microbenchmark
measured roughly 436 million Swift Philox words/s and 411 million words/s for the
canonical Random123 C++ implementation. Treat those figures as directional only;
the exact harness was not retained, so the table above is the reproducible baseline.
