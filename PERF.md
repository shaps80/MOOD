# Performance Baselines

These are reference measurements for detecting material performance regressions in Pixl's low-level libraries. They are not hard pass/fail thresholds: compare new results with the baseline from the same runtime and similar hardware conditions.

## Current profiling record

This document contains separate profiling records for specific low-level components. It does not describe whole-backend, rendering, GPU, frame-time, or game performance.

## PixlExec — arm64 macOS

Recorded on 2026-07-12 after extracting the lane prototype into the official `PixlExec` target.

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
- SIMD tests are workload examples using aligned `SIMD8<UInt64>` processing. PixlExec itself is SIMD-width agnostic.

Command:

```sh
swiftly run swift test -c release --filter PixlExec
```

### Results

| Workload | Wall time | CPU time | Instructions retired | Physical-memory delta |
|---|---:|---:|---:|---:|
| Lifecycle + dynamic scalar | 3.888 ms | 31.289 ms | 579.150 M | 209.720 KB |
| Hot single-lane scalar | 21.547 ms | 21.770 ms | 563.191 M | 0 KB |
| Hot static scalar | 4.064 ms | 30.112 ms | 575.281 M | 0 KB |
| Hot dynamic scalar | 3.678 ms | 30.518 ms | 576.109 M | 6.554 KB |
| Hot single-lane SIMD8 | 8.356 ms | 8.555 ms | 292.961 M | 0 KB |
| Hot dynamic SIMD8 | 3.512 ms | 29.234 ms | 305.842 M | 13.107 KB |

The dynamic physical-memory deltas came from one or two initial 32 KB page commitments; remaining measured samples were zero. Treat these as lazy worker/runtime memory commitment, not steady per-run allocation. XCTest's peak physical-memory metric describes the whole test process and depends on test order, so it is intentionally not used as a component baseline.

The reusable group-owned barrier preserved performance while removing barrier allocation from repeated `run` calls. Dynamic scalar was approximately 9.5% faster than static scalar in this record. SIMD8 reduced the single-lane example by approximately 61.2%; its incremental benefit was smaller once dynamic multi-lane execution approached shared-memory limits.

## ResourcePool

The following represents the last accepted profiling record for `ResourcePool` specifically, recorded on 2026-07-11.

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
| Cold start lifecycle | 0.656 ms | 1.45 ns |
| Sequential lookup | 0.108 ms | 0.72 ns |
| Random-order lookup | 0.197 ms | 1.31 ns |
| In-place update | 0.088 ms | 0.59 ns |
| Remove/reinsert churn | 0.284 ms | 0.94 ns |

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
./.scripts/test native
./.scripts/test wasm
./.scripts/browser-test chrome
./.scripts/browser-test safari
```
