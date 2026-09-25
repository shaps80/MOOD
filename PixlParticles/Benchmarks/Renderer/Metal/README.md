# Metal renderer benchmark

Build only from PixlParticles: `.scripts/benchmark-rendering build`.
Run: `.scripts/benchmark-rendering run 2000000 1920 1080`.

The standalone package depends on the production PixlParticles and PixlMetal
packages. The script compiles the production Metal shaders into the SwiftPM
resource bundle. Each invocation cleans native build outputs before compiling:
cross-module optimization otherwise can retain stale dependency implementations
and mismatch Swift dispatch dimensions with newly compiled shaders. No copied
rendering implementation or benchmark-only API.

Runs the hardware reference and automatic production path sequentially, each
with point and billboard workloads, with a fixed seeded sphere,
paused simulation, default billboard size, no point LOD, and an explicit drawable
pixel size. Thirty warmup frames precede 180 samples per mode. One frame completes
before the next submission: this isolates GPU work and is not a throughput/FPS
benchmark. A private offscreen Metal texture replaces window presentation, so the benchmark
also runs with a locked or sleeping display. Production resources, render passes,
encoders, shaders and counters are unchanged.

Reports total, preparation, diagnostics, draw, vertex and fragment GPU times as
median/p95 milliseconds, with valid-sample counts. It uses the same production
counter sampling as the editor. Missing counters are unavailable, not zero.
No preparation passes is a valid zero. Draw excludes the editor guides/overlays;
the editor's Draw row includes them. Stages overlap, so their sums are not total
frame time. Timestamps measure stage duration, not hardware utilization or an
exact breakdown of overdraw costs.

Keep GPU performance runs sequential. Record accepted results in PERF.md only
with the device, drawable size, workload and timing configuration.

## Image checks

Run `.scripts/benchmark-rendering run validate` for GPU image comparisons of
dense, sparse, odd-size, perspective and transparent workloads. Alternating HDR
palette colours test nearest-particle selection. Both points and billboards are
covered, including rotation, all facing modes, screen sizing, oversized and
zero-area shapes. Translucent, sparse and zero-area cases must be exact;
compute coverage permits at most 0.1% differing pixels for subpixel rounding.
Oversized opaque geometry permits max(4, pixel count / 100000) differing pixels.
These are regression limits, not proof of bit identity.

The suite also requires exact images for ordered alpha, zero-alpha depth writes,
equal-depth ties, same-area viewport resizing, near-plane clipping and opacity
transitions. Run `run validate-boundaries` for just the six transition checks.

Pass a fourth argument after count/width/height to capture raw RGBA16Float images:
`.scripts/benchmark-rendering run 2000000 2852 1916 /tmp/particles`.
Capture runs use only two warmup frames and one measured frame; do not use their
timings as performance evidence. Filenames identify reference/automatic and mode.

The reference comparison is confined to this harness; the application has no
optimization switch. Its selection is automatic based on GPU capabilities,
opaque palette entries, particle density and projected footprint. Points and
billboards share the production raster pass.

Append `translucent` to count/width/height for the alpha-0.4 benchmark, retaining
30 warmup frames and 180 measured samples. Append `quick` for a two-warmup,
one-sample smoke check only; its timings are not performance evidence.
