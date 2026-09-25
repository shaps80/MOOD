# Metal renderer benchmark

Build only from PixlParticles: `.scripts/benchmark-rendering build`.
Run: `.scripts/benchmark-rendering run 2000000 1920 1080`.

The standalone package depends on the production PixlParticles and PixlMetal
packages. The script compiles the production Metal shaders into the SwiftPM
resource bundle. No copied rendering implementation or benchmark-only API.

Runs point and billboard workloads sequentially, with a fixed seeded sphere,
paused simulation, default billboard size, no point LOD, and an explicit drawable
pixel size. Thirty warmup frames precede 180 samples per mode. One frame completes
before the next submission: this isolates GPU work and is not a throughput/FPS
benchmark. A small visible macOS window supplies real CAMetalLayer drawables.

Reports total, preparation, diagnostics, draw, vertex and fragment GPU times as
median/p95 milliseconds, with valid-sample counts. It uses the same production
counter sampling as the editor. Missing counters are unavailable, not zero.
No preparation passes is a valid zero. Draw excludes the editor guides/overlays;
the editor's Draw row includes them. Stages overlap, so their sums are not total
frame time. Timestamps measure stage duration, not hardware utilization or an
exact breakdown of overdraw costs.

Keep GPU performance runs sequential. Record accepted results in PERF.md only
with the device, drawable size, workload and timing configuration.
