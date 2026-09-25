# Compute preparation tuning — provisional results

Scope: compute preparation only. Simulation, particle storage, draw submission,
translucent compositing and renderer buffer allocations are unchanged. The only
retained shader change declares the existing 128-thread coverage dispatch limit
with `max_total_threads_per_threadgroup(128)`.

## Paired measurements

Apple M4 Pro; Release production renderer and shaders; 8,000,000 particles;
2852 × 1916 offscreen drawable; paused seeded sphere; default opaque billboards;
LOD disabled. Thirty warmup frames and 180 measured frames per mode. All runs
sequential. The user's editor remained running; background GPU/CPU contention
is present, particularly in p95 values. This scene is not matched to the user's
cropped 10.97 ms editor capture. Do not compare those absolute timings directly.

| Coverage kernel | Preparation median | Total GPU median | Total p95 |
| --- | ---: | ---: | ---: |
| Original, first run | 21.638 ms | 21.864 ms | 24.639 ms |
| Compiler limit 128, first run | 20.537 ms | 20.762 ms | 24.662 ms |
| Original, repeated | 21.181 ms | 21.825 ms | 24.535 ms |
| Compiler limit 128, repeated | 20.567 ms | 20.792 ms | 24.559 ms |

Preparation median improved 2.9–5.1%; total GPU median improved 4.7–5.0%.
There is no demonstrated p95 improvement. Point total GPU medians remain near
3.00 ms. A final clean two-million-particle run measured 1.016 ms for points and
5.468 ms for billboards; this is a smaller-workload regression check, not evidence
of an improvement over an earlier run under different background load.

The attribute tells the compiler the actual dispatch limit, consistent with
[Apple's compute pipeline guidance](https://developer.apple.com/documentation/metal/mtlcomputepipelinedescriptor/maxtotalthreadsperthreadgroup).
Register spills were not measured; the precise hardware reason for this small
repeatable median improvement is unconfirmed. No memory saving is claimed.

## Rejected experiments

| Experiment | 8M billboard preparation median | Outcome |
| --- | ---: | --- |
| Eight coverage lanes per particle, clean build | 20.184 ms | Similar small total-time gain; more complexity, removed |
| Separate 32-bit depth and identity phases | 36.648 ms | Slower, removed |
| Flattened coverage loop | 21.235 ms | No meaningful gain, removed |
| 32-thread groups and compiler limit | 21.575 ms | No meaningful gain, removed |
| Inner loop unrolled four times | 22.903 ms | Slower, removed |

A direct atomic read before the 64-bit minimum was rejected by the compiler:
this Metal atomic type does not provide the required load operation. No unsafe
non-atomic concurrent read was substituted.

Early four/eight-lane timings were invalid: the incremental native build kept
an old optimized Swift dispatch count alongside the changed Metal kernel. GPU
image checks caught missing particles. Clean rebuilding restored correct output
and eliminated the apparent large speedup. Those timings are excluded from all
results. The benchmark script now cleans native outputs before compiling so
cross-module optimized callers and shaders remain paired.

## Verification and limits

The retained shader passed all 47 existing GPU image comparisons, including
ordered transparency, depth ties, zero-alpha depth writes, resize and near-plane
fallbacks. Existing compute/fixed-function subpixel tolerances are unchanged.
macOS Release compilation passed. No iOS-specific code changed. No application
switch, extra buffer or alternate rendering algorithm remains.

This is a modest compute tuning result, not a substantial rendering speedup.
It does not establish atomic contention as the dominant bottleneck. Larger
changes need finer shader profiling to separate coverage arithmetic, memory
traffic and atomic throughput before adding complexity or scratch storage.

Reproduce from PixlParticles:

```sh
.scripts/benchmark-rendering run 8000000 2852 1916
.scripts/benchmark-rendering run 2000000 2852 1916
.scripts/benchmark-rendering run validate
```

These implementation timings remain provisional; accepted PERF.md contains the
user-reported editor results separately.
