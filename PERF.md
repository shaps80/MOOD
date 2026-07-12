# Performance Baselines

These are reference measurements for detecting material performance regressions in Pixl's low-level libraries. They are not hard pass/fail thresholds: compare new results with the baseline from the same runtime and similar hardware conditions.

## Current profiling record

This document contains separate profiling records for specific low-level components. It does not describe whole-backend, rendering, GPU, frame-time, or game performance.

## PixlConcurrency — arm64 macOS

Recorded on 2026-07-12 after extracting `PixlConcurrency` into its own package, moving OS threading behind `PixlConcurrencyC`, correcting worker lifetime, separating work/completion signalling, isolating barrier atomics, tuning the spin threshold, and validating the final tiered-CMO configuration.

### Methodology

- Swift 6.3.2, release configuration.
- XCTest `measure(metrics:)` with clock, CPU, and physical-memory metrics.
- Five measured samples per test in this command-line run.
- 4,000,000 `UInt64` elements processed for 20 iterations.
- Ten explicit lanes for static and dynamic multi-lane tests, matching the machine's discovered performance-core count.
- Eight dynamically claimable chunks per lane, aligned to eight elements.
- The calling thread participates as lane zero.
- Lifecycle creates and destroys the execution group, workers, context, buffers, cursor, and performs one dynamic run inside each measured sample.
- Hot tests create the persistent group and preallocated context before measurement; only repeated `ExecutionGroup.run` calls are measured.
- SIMD tests are workload examples using aligned `SIMD8<UInt64>` processing. PixlConcurrency itself is SIMD-width agnostic.

The lifecycle result now includes real worker shutdown and joining. Earlier lifecycle records retained their execution groups through worker ownership and therefore did not measure complete teardown correctly.

Command:

```sh
swiftly run swift test -c release --filter PixlConcurrencyPerformanceTests
```

### Results

| Workload | Wall time |
|---|---:|
| Lifecycle + dynamic scalar | 3.856 ms |
| Hot single-lane scalar | 21.496 ms |
| Hot static scalar | 4.264 ms |
| Hot dynamic scalar | 4.047 ms |
| Hot single-lane SIMD8 | 8.315 ms |
| Hot dynamic SIMD8 | 3.533 ms |

XCTest also records CPU time, retired instructions, and physical memory for each run. Wall time remains the primary comparison here because CPU scheduling and whole-process peak memory vary with test order. Hot runs allocate no steady per-run library storage.

## ResourcePool — historical record

The custom native, WasmKit, browser, and Metal benchmark runners used for this record have been removed. ResourcePool correctness now lives directly in Swift Testing; native performance coverage lives directly in XCTest. Preserve these numbers only as historical context, not as a currently reproducible benchmark matrix.

The following represents the last accepted profiling record for `ResourcePool` specifically, recorded on 2026-07-12 with provider-side aggressive CMO restored.

Every runtime executed the same platform-neutral suite from `PixlPlatformTestSupport`:

- Cold start lifecycle: allocate a fixed pool, insert 150,000 resources, update every resource, then remove every resource.
- Sequential lookup: look up all 150,000 live resources in slot order and accumulate a checksum.
- Random-order lookup: look up the same resources after a deterministic handle shuffle and accumulate a checksum.
- In-place update: update all 150,000 live resources through `ResourcePool.update`.
- Remove/reinsert churn: remove all 150,000 resources, then reuse all 150,000 slots through the free list.

The native record used the release standalone runner on arm64 macOS. The WasmKit record cross-compiled that runner with the Swift WASM SDK and executed the resulting WASI binary through WasmKit. The browser record packaged the same shared suite with PackageToJS and executed it as browser WASM in Chrome and Safari; the measured browser run followed a one-second idle delay and one discarded full-suite JIT warm-up.

## ResourcePool methodology

- Swift 6.3.2, release configuration.
- Provider-side aggressive cross-module optimization is enabled for `PixlPlatform`.
- 150,000 live `UInt64` resources.
- Lookup and update workloads use 100 measured iterations.
- Cold lifecycle and remove/reinsert churn use 10 measured iterations.
- Browser runs wait one second, execute one complete discarded suite for JIT warm-up, then run the measured suite.
- Expected checksum: `57984720018213657`.

## Native — arm64 macOS

| Workload | Average | Per operation |
|---|---:|---:|
| Cold start lifecycle | 0.448 ms | 0.99 ns |
| Sequential lookup | 0.082 ms | 0.55 ns |
| Random-order lookup | 0.177 ms | 1.18 ns |
| In-place update | 0.083 ms | 0.55 ns |
| Remove/reinsert churn | 0.296 ms | 0.98 ns |

## Metal ResourcePool runtime scenario — arm64 macOS

Recorded on 2026-07-12 using 256 distinct real `MTLTexture` objects. The suite performs 524,288 sequential or deterministic-random resolutions, matching the attachment-assignment shape in `MetalQueue.encode`. It separately measures pool resolution, direct Metal attachment binding, their combined path, transient drawable churn, and single-texture replacement.

Historical command (target removed):

```sh
swiftly run swift run -c release PixlMetalPlatformBenchmarkRunner
```

| Workload | Previous | Current | Change |
|---|---:|---:|---:|
| Pool-only sequential resolution | 1.641 ms | 1.661 ms | 1.2% slower |
| Direct sequential attachment binding | 7.205 ms | 7.133 ms | 1.0% faster |
| Sequential texture resolution | 8.483 ms | 8.543 ms | 0.7% slower |
| Pool-only random resolution | 1.630 ms | 1.589 ms | 2.5% faster |
| Direct random attachment binding | 7.168 ms | 7.161 ms | unchanged |
| Random-order texture resolution | 8.453 ms | 8.449 ms | unchanged |
| Transient drawable churn | 0.450 ms | 0.436 ms | 3.1% faster |
| Single texture replacement | 1.164 ms | 1.192 ms | 2.4% slower |

These changes are within expected run variance. The pool remains a small part of the combined Metal attachment-binding cost.

## Release cross-module optimization policy

The accepted configuration keeps every Swift library target cross-module optimizable while applying the aggressive mode only where benchmarks prove it matters:

- `-enable-cmo-everything`: `PixlPlatform`, `PixlConcurrency`.
- `-cross-module-optimization`: `Pixl`, `PixlGraphics`, `Pixl2D`, `Pixl3D`, `PixlMetalPlatform`.

Applying `-enable-cmo-everything` to every linked module caused duplicate Swift standard-library symbols. The tiered configuration links the release Game executable, retains concrete `ResourcePool<UInt64>`, `ResourcePool<MTLTexture>`, `ExecutionGroup<BenchmarkProgram>`, and `ExecutionState<BenchmarkProgram>` specializations, and preserves the accepted performance records above.

## WASM/WASI — WasmKit

| Workload | Average | Per operation |
|---|---:|---:|
| Cold start lifecycle | 29.800 ms | 66.22 ns |
| Sequential lookup | 2.395 ms | 15.96 ns |
| Random-order lookup | 2.629 ms | 17.52 ns |
| In-place update | 2.554 ms | 17.02 ns |
| Remove/reinsert churn | 20.250 ms | 67.50 ns |

WasmKit is the stable automated portability and regression baseline. It is not a predictor of browser execution speed.

## Browser WASM — Chrome 150

User agent:

```text
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36
```

| Workload | Average | Per operation | Minimum | Maximum |
|---|---:|---:|---:|---:|
| Cold start lifecycle | 1.570 ms | 3.48 ns | 1.400 ms | 1.700 ms |
| Sequential lookup | 0.113 ms | 0.75 ns | 0.000 ms | 0.200 ms |
| Random-order lookup | 0.194 ms | 1.29 ns | 0.100 ms | 0.600 ms |
| In-place update | 0.117 ms | 0.78 ns | 0.000 ms | 0.200 ms |
| Remove/reinsert churn | 1.270 ms | 4.23 ns | 1.200 ms | 1.300 ms |

Chrome and Safari both completed the browser suite and showed similar performance. An exact Safari sample was not recorded for this baseline.

The `0.000 ms` minima are browser-clock quantization, not zero-cost operations. The 100-iteration averages are still suitable for coarse regression detection; batch more work per timed sample if finer browser resolution becomes necessary.

## Commands

From the repository root:

```sh
./.scripts/test
```
