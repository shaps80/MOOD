# Performance Baselines

These are reference measurements for detecting material performance regressions in Pixl's low-level libraries. They are not hard pass/fail thresholds: compare new results with the baseline from the same runtime and similar hardware conditions.

## Current profiling record

This document contains separate profiling records for specific low-level components and one representative CPU frame. It does not describe GPU execution, presentation, or complete game performance.

## Representative CPU frame — native and WebAssembly

Recorded on 2026-08-31 before the planned memory-ownership redesign. The
standalone `Pixl/Benchmarks` runner executes one deterministic production
workload without a window, GPU, assets, or presentation timing. It is the
accepted before-change baseline for comparing CPU and retained-memory effects
of that redesign.

### Methodology

- Swift 6.4 development snapshot dated 2026-08-26, release configuration.
- Native host: Apple M4 Pro with 10 performance and four efficiency cores,
  48 GB memory, arm64 macOS 27.0.
- WebAssembly: the repository's matching Swift 6.4 WASI SDK, compiled directly
  with `swiftc -O -whole-module-optimization -Xcc -msimd128` and no
  `-num-threads`, then executed through Node.js 24.2.0's WASI runtime.
- 100,000 retained submissions: 60% sprites, 30% analytic shapes, and 10%
  immediate primitives. Exactly 10,000 submissions are visible with the same
  family distribution; eight layers, varied orders, textures, samplers, blend
  modes, and shape kinds exercise lowering, culling, ordering, and batching.
- 5,120 colliders: 4,096 static rectangles and 1,024 moving rectangles. Every
  frame updates the dynamic bounds, advances exact collision, performs 64
  overlap queries, and performs 32 nearest-hit ray casts.
- Ten warm-up frames precede 51 measured frames. Each row reports the
  distribution across those frames. Cases run sequentially.
- Total CPU frame includes collision updates, advance, queries, ray casts,
  render submission, and render-queue execution. It excludes game logic,
  resource resolution, GPU command encoding, GPU execution, and presentation.
- Correctness requires 10,000 visible submissions, 1,024 directed collision
  reports, 1,280 overlap-query hits, 32 ray hits, and checksum
  `14257096247257000787` on both runtimes.
- Three complete native runs produced total-frame medians of 3.529, 3.456,
  and 3.494 ms. Five complete direct-WMO WebAssembly runs produced 5.785,
  5.620, 5.536, 5.488, and 5.509 ms. Each table retains its middle complete
  run rather than combining stage values from different runs.

### CPU results

| Stage | Native median | Native p95 | WASI median | WASI p95 |
| --- | ---: | ---: | ---: | ---: |
| Total CPU frame | 3.494 ms | 3.749 ms | 5.536 ms | 5.834 ms |
| Collision updates | 0.008 ms | 0.010 ms | 0.009 ms | 0.009 ms |
| Collision advance | 0.392 ms | 0.605 ms | 0.480 ms | 0.683 ms |
| Collision overlap queries | 0.039 ms | 0.067 ms | 0.075 ms | 0.092 ms |
| Collision ray casts | 0.006 ms | 0.011 ms | 0.008 ms | 0.012 ms |
| Render submission | 1.454 ms | 1.556 ms | 2.293 ms | 2.360 ms |
| Render lowering | 1.395 ms | 1.519 ms | 2.420 ms | 2.515 ms |
| Render culling | 0.096 ms | 0.114 ms | 0.157 ms | 0.161 ms |
| Render layer binning | 0.026 ms | 0.042 ms | 0.029 ms | 0.046 ms |
| Render ordering | 0.017 ms | 0.019 ms | 0.020 ms | 0.022 ms |
| Render batching | 0.026 ms | 0.032 ms | 0.051 ms | 0.059 ms |
| Render instances | 0.000 ms | 0.000 ms | 0.000 ms | 0.000 ms |

The WebAssembly result is a portable regression baseline, not a browser-speed
prediction. SwiftPM release compilation of this same benchmark incorrectly
measured 97.867 ms median because the Swift 6.4 driver added `-num-threads` and
destroyed crucial cross-file optimisation. That result is rejected build-path
evidence, not Pixl performance. The checked-in WASM command compiles the real
production modules and benchmark directly with the accepted workaround.

### Native memory

| Point | Resident memory | Change |
| --- | ---: | ---: |
| Before workload construction | 5.81 MiB | — |
| After deterministic workload construction | 47.88 MiB | +42.06 MiB |
| After warm-up touched retained execution storage | 103.11 MiB | +55.23 MiB |
| After 51 measured frames | 103.11 MiB | +0.00 MiB |
| Peak resident memory | 103.11 MiB | — |

These are whole-process resident measurements. They deliberately include the
benchmark's retained submission descriptions and collision workload, so they
are suitable for matched before/after comparison rather than exact ownership
accounting. The unchanged post-warm-up reading confirms no measurable
steady-state resident growth in this run. WASI does not currently expose a
comparable resident-memory query through this runner.

Commands from the repository root:

```sh
./.scripts/benchmark native
./.scripts/benchmark wasm
```

Pass `--json` after the runtime for machine-readable output.

## PixlText layout — arm64 macOS

Recorded on 2026-07-31 after removing repeated GSUB/GPOS plan construction and duplicate variable-font work from the retained layout path.

### Methodology

- Swift 6.4, arm64 macOS; exact SoC was not recorded.
- Exact three-paragraph `PixlTextPlayground` workload using `/Library/Fonts/SF-Pro.ttf`, a 520-point layout width, three font sizes, paragraph spacing, and a retained `Font.LayoutDebugSession`.
- Twenty baseline iterations before the changes; 25 iterations after the changes, following one discarded warm-up layout.
- Whole measured calls include font declaration/override construction, shaping, line breaking, paragraph composition, and debug bounds materialization.
- Variable-weight samples continuously change the selected paragraph's `wght` coordinate from 250 through 850 in steps of 25.
- Font-byte loading, initial face registration, SwiftUI state/event handling, Canvas drawing, and presentation are excluded.
- The retained regression harness enforces a 16.667 ms median budget in Debug and also verifies that variable-weight extremes produce different run geometry.

Harness: `Pixl/Sources/PixlText/PerformanceTests/PixlTextLayoutPerformanceTests.swift`.

### Results

| Workload | Debug before | Debug after | Release after |
| --- | ---: | ---: | ---: |
| Unchanged layout | 301 ms | 8.48 ms | 0.39 ms |
| Paragraph alignment | 302 ms | 8.59 ms | 0.32 ms |
| Font size | 302 ms | 8.58 ms | 0.45 ms |
| Variable weight | 315 ms | 11.99 ms | 0.42 ms |

The dominant regression was rebuilding and sorting complete GSUB/GPOS plans for every run and every layout. The accepted implementation retains immutable plan topology per face/session, shares equivalent selected plans, resolves GPOS variation deltas only for matched rules, resolves final advances once, and reuses repeated-glyph render bounds through bounded caller-owned scratch storage.

## Render pipeline prototype — arm64 macOS

Recorded on 2026-07-20 from the isolated `Pixl/Prototypes/RenderPipelinePrototype` Xcode application after validating the intended single-threaded CPU data flow. This is a retained architecture prototype, not an implementation or performance baseline for Pixl, PixlFoundation, PixlPlatform, Metal rendering, WebGPU rendering, or a complete game frame. Keep it as a directional reference while porting the design into Pixl; establish new accepted Pixl baselines after the real implementation exists.

### Prototype methodology

- Xcode Release configuration on the arm64 macOS development machine; exact SoC was not recorded.
- Deterministic fixed-seed input of 500,000 sprite submissions.
- 300,029 submissions visible to the union of two overlapping camera views.
- Eight sparse public layer values and four deterministic randomized material descriptions.
- One-second running medians reported by the prototype.
- Measured total contains only lowering, contiguous scalar multi-view culling, dense layer binning, per-layer radix ordering, consecutive batch formation, and logical instance finalization.
- Entity generation, diagnostic construction, hover lookup, SwiftUI, Metal encoding/drawing, GPU execution, and presentation are excluded.
- The instance stage is zero because lowering writes one ordinal-aligned instance record and views retain source-ordinal streams rather than copying another full CPU instance record.

### Accepted prototype reference

| Stage | 500,000 submissions |
| --- | ---: |
| Lowering | 1.259 ms |
| Culling | 2.686 ms |
| Layer binning | 0.502 ms |
| Ordering | 0.323 ms |
| Batching | 1.923 ms |
| Instances | 0.000 ms |
| Measured total | 6.693 ms |
| Prototype throughput | 149.1 pipeline frames/s |

The same final scalar design was also observed below 16 ms with 1,000,000 submissions and at approximately 0.1 ms with 10,000 submissions. Those were runtime observations rather than captured per-stage records, so treat them as scaling checks rather than precise baselines.

Manual cross-entity SIMD, per-AABB `SIMD2` comparison, frame-rebuilt uniform spatial grids, and retained per-sprite uniform spatial grids were measured and rejected. They provided no useful improvement or were materially slower while increasing data-layout and lifecycle complexity. The accepted prototype therefore retains compact ordinal-aligned streams and a contiguous scalar bounds traversal. Persistent world visibility or coarse tilemap/chunk acceleration remains a separate higher-level concern.

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
