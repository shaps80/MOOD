# Performance Baselines

These are reference measurements for detecting material `PixlBackend` performance regressions. They are not hard pass/fail thresholds: compare new results with the baseline from the same runtime and similar hardware conditions.

## Current profiling record

This document represents the last accepted profiling record for `ResourcePool` specifically, recorded on 2026-07-11. It does not describe whole-backend, rendering, GPU, frame-time, or game performance.

Every runtime executed the same platform-neutral suite from `PixlBackendTestSupport`:

- Cold start lifecycle: allocate a fixed pool, insert 150,000 resources, update every resource, then remove every resource.
- Sequential lookup: look up all 150,000 live resources in slot order and accumulate a checksum.
- Random-order lookup: look up the same resources after a deterministic handle shuffle and accumulate a checksum.
- In-place update: update all 150,000 live resources through `ResourcePool.update`.
- Remove/reinsert churn: remove all 150,000 resources, then reuse all 150,000 slots through the free list.

The native record used the release standalone runner on arm64 macOS. The WasmKit record cross-compiled that runner with the Swift WASM SDK and executed the resulting WASI binary through WasmKit. The browser record packaged the same shared suite with PackageToJS and executed it as browser WASM in Chrome and Safari; the measured browser run followed a one-second idle delay and one discarded full-suite JIT warm-up.

## ResourcePool methodology

- Swift 6.3.2, release configuration.
- Provider-side aggressive cross-module optimization is enabled for `PixlBackend`.
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
