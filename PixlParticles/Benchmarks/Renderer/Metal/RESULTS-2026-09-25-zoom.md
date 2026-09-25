# Enlarged opaque billboard refinement — provisional results

## Workload and comparison

Apple M4 Pro, Release production renderer/shaders, 10,000,000 paused particles
on a seeded sphere surface (radius 150), opaque palette, 2852 × 1916 offscreen
drawable, no LOD. Orthographic zoom 1.25 and billboard size 4 produce dense,
overlapping enlarged footprints without relying on widespread offscreen rejection.
Thirty warmup frames, 180 measured frames per mode; one completed submission at a
time. Benchmarks ran sequentially. The user's editor remained running, so timing
variance and background contention remain. This is not the exact editor document
or a prediction of its FPS. Every benchmark invocation clean-builds production
Swift and Metal sources.

The comparison baseline includes the diagnostics fix. The final comparison was
candidate normal/dense, baseline normal/dense, then cleaned candidate normal/dense.

| Enlarged billboards | Original fallback | Final refinement |
| --- | ---: | ---: |
| Total GPU median | 108.038 ms | 26.971 ms |
| Total GPU p95 | 160.009 ms | 32.502 ms |
| Preparation median | 1.087 ms | 26.760 ms |
| Draw median | 106.312 ms | 0.205 ms |
| Process physical footprint | 1605.617 MB | 680.707 MB |
| Metal reported allocations | 310.166 MB | 350.519 MB |

Total median is about 4× faster; process footprint is 58% lower despite reserving
40 MB of particle indices. Earlier sequential repetitions measured original totals
98–102 ms and refined totals 25–27 ms. They support the same direction, but are
not independent controlled trials. Process figures are snapshots after each mode,
not peak captures. The original point-to-billboard memory jump happened without a
change in Metal's reported allocations; this implicates rendering-internal costs,
but does not identify their exact allocation classes.

Ordinary billboards (zoom 1, size 1) remain essentially unchanged: total median
12.964 → 13.019 ms, p95 15.506 → 15.642 ms. Preparation timestamps remain valid.
Points do not allocate the new index/tile buffers. Opaque billboards reserve those
buffers even when the ordinary coverage pass succeeds. Transparent behavior and
simulation are unchanged; no translucent speedup is claimed.

## Retained implementation

The 256-pixel cheap pass stays in place. On overflow, GPU-only refinement seeds
depth from one particle in sixteen, builds a conservative 8×8-tile summary,
compacts unoccluded original indices, and rasterizes seeds/survivors cooperatively
with 32 lanes per particle. Pixel coverage and nearest-depth/index selection are
shared with the ordinary pass. Empty pixels and equal depths cannot be rejected.
No approximate particle dropping, application switch, or CPU readback is used.
Indirect dispatch avoids extra particle work when refinement is unnecessary.

Refinement remains bounded at 4096 bounding-box pixels per footprint. Extreme
footprints still fall back to ordered hardware geometry and can still exhibit a
memory/time cliff. This is not a universal solution for arbitrary full-screen
billboards or transparent overdraw.

## Rejected experiments

- Raising the original serial coverage cap alone caused severe regressions.
- Disabling opaque blending and reusing an ICB for fallback did not materially
  improve the dense workload.
- A per-pixel seeded-depth snapshot was slower and needed more scratch.
- Serial seeded refinement reduced memory but was still about 89 ms.
- Denser seeds plus compaction and cooperative coverage produced the useful gain.
- Flattening ordinary pixel traversal regressed the normal workload; original
  traversal is retained there.

## Validation

57 GPU image comparisons pass, including alternating HDR palettes, dense overlap,
perspective, every facing mode, opacity, original-index depth ties, near clipping,
resize and transitions through refinement/points/ordinary coverage. Existing
subpixel tolerances remain unchanged; exact cases remain exact. 76 visibility
checks pass. Telemetry counts visibility before occlusion; timestamps stay per frame.
macOS Release compilation and all seven isolated renderer unit tests pass after
integration. The complete particle-package suite was not used: existing simulation
tests still reference the removed `System(particleCount:)` initializer.

Reproduce:

```sh
.scripts/benchmark-rendering run 10000000 2852 1916 automatic-only zoom=1.25 size=4
.scripts/benchmark-rendering run 10000000 2852 1916 automatic-only
.scripts/benchmark-rendering run validate
```

These timings remain provisional; accepted user observations live in PERF.md.
