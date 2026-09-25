# Shared point and billboard rasterization — provisional results

Apple M4 Pro, macOS Release, production renderer and shaders. Paused seeded
sphere, 2,000,000 particles, 2852 × 1916 RGBA16Float offscreen drawable, default
billboard dimensions, no LOD. Each mode uses 30 warmup and 180 measured frames,
one completed frame at a time. Hardware reference and automatic implementation
run sequentially; opaque and translucent runs also run sequentially. The user's
editor remained running throughout: these are paired measurements, not an idle
machine claim. No editor guides are drawn. GPU stage intervals can overlap;
compare Total rather than adding stages. Results await editor acceptance and
have not been promoted to PERF.md.

| Material / shape | Reference median | Shared median | Reference p95 | Shared p95 |
| --- | ---: | ---: | ---: | ---: |
| Opaque point | 6.883 ms | 0.978 ms | 6.964 ms | 0.991 ms |
| Opaque billboard | 9.721 ms | 5.431 ms | 12.494 ms | 5.444 ms |
| Alpha 0.4 point | 6.925 ms | 6.931 ms | 7.026 ms | 8.185 ms |
| Alpha 0.4 billboard | 9.676 ms | 9.744 ms | 10.995 ms | 9.896 ms |

Opaque billboard median is 44.1% lower; point median is 85.8% lower than the
hardware reference, maintaining the earlier point optimization. Transparent
medians are effectively unchanged (billboard +0.7%); no transparency speedup
is claimed. Background contention makes individual p95 comparisons less stable.

| Automatic opaque stage, median | Point | Billboard |
| --- | ---: | ---: |
| Preparation | 0.734 ms | 5.231 ms |
| Diagnostics | 0.166 ms | 0.165 ms |
| Draw | 0.234 ms | 0.189 ms |
| Vertex | 0.006 ms | 0.006 ms |
| Fragment | 0.228 ms | 0.183 ms |

## Implementation and memory

One ParticleRasterPass and shared projection helper serve both shapes. Dense
opaque coverage finds nearest depth with particle-index tie-breaking in compute;
ordered hardware geometry preserves current translucent blending/depth writes.
Compute scratch remains 8 bytes per viewport pixel (43,715,456 bytes here), plus
16 bytes of indirect arguments. No new per-particle streams or fragment lists.
This is an allocation calculation, not a measured process-memory reduction.

A footprint exceeding 256 bounding-box pixels triggers GPU indirect geometry
for the entire batch, suppressing compute resolve. Large and near-plane shapes
remain supported; their speedup is not implied by the default-size result.

## Validation

- 35 GPU comparisons: five scenes × seven point/billboard configurations,
  including all facing modes, rotation, world/screen sizing, oversized and
  zero-area shapes. Transparent and sparse cases match reference exactly.
- Six exact overlap/order checks: ordered alpha, zero-alpha depth writes and
  opaque equal-depth ties, each for points and billboards.
- Six exact persistent-renderer transitions: same-area viewport resize,
  near-plane clipping, opacity changes and returning to opaque rendering.
- All 47 comparisons pass. Compute coverage allows 0.1% differing pixels for
  fixed-function boundary rounding; oversized opaque geometry has a much tighter
  max(4, pixel count / 100000) limit. This is not universal pixel identity.
- Seven isolated renderer tests pass; macOS editor Release build succeeds.
- Full package tests retain an unrelated compile failure in legacy particle
  tests calling removed System(particleCount:); not changed by this work.

Resize validation found and corrected an opposing-edge inclusion bug by applying
consistent top-left coverage rules. No iOS-specific code was changed or built.

## Experiments rejected

Ordered hierarchical tile lists preserved compositing but cost approximately
19–31 ms for points and 108–259 ms for billboards, including a cached-bounds
variant. Mesh-shader projection batches provided no reliable transparent gain.
An oversized triangle with fragment masking increased billboard cost to roughly
11.8 ms. An extra atomic depth buffer increased point cost without improving
billboards. These implementations and their additional storage were removed.

## Reproduction

From PixlParticles, run sequentially:

```sh
.scripts/benchmark-rendering run 2000000 2852 1916
.scripts/benchmark-rendering run 2000000 2852 1916 translucent
.scripts/benchmark-rendering run validate
```

The hardware reference is a harness-only adapter capability override. No user
switch or benchmark-only rendering API was introduced.
