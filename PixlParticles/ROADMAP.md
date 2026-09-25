# PixlParticles Roadmap

Work through one decision at a time. Deterministic simulation remains the first
constraint; GPU execution and data-oriented storage remain the scaling path.

## 1. Quad Billboard Rendering — Complete

- [x] Keep point rendering as one physical framebuffer pixel.
- [x] Add one authored standalone renderer definition selecting point or
  billboard mode.
- [x] Lower fixed two-component size and scalar radian rotation as per-draw GPU
  constants rather than repeated particle storage.
- [x] Add world-unit and physical-pixel billboard size spaces.
- [x] Add camera, camera-plane, and camera-position/world-up facing modes.
- [x] Expand procedural four-vertex triangle strips from compacted particle
  indices and submit one indirect instanced draw.
- [x] Reuse one GPU culling/compaction path with conservative billboard bounds.
- [x] Persist all renderer settings and expose live inspector editing without
  restarting simulation.
- [x] Complete manual visual validation on the user's machine.
- [x] After explicit visual approval, compare point and billboard performance;
  record only accepted results in `PERF.md`.

Sprites, textures, configurable pivots, billboard LOD, picking, and selected
particle axis/bounds diagnostics remain deferred until the solid-colour path is
validated.

## 2. Colour Authoring and Diagnostics — Active

- [x] Expose GPU total, preparation, diagnostics, draw, vertex, and fragment
  timings in the editor and a production-Metal benchmark package. Sample GPU
  stage counters with bounded reusable storage and retain unavailable values.
  macOS benchmark measurements and GPU image comparisons now run offscreen.

- [x] Draw non-LOD particles directly from shared simulation storage; remove
  per-particle renderer compaction buffers on that path, preserve bounds and
  visible-count diagnostics, and reuse immutable Metal indirect draw commands.
  macOS compilation only; runtime and memory validation remain with the user.

- [x] Move editor simulation ownership into a lazy document-owned object; keep
  ContentView.system non-optional, deduplicate simulation configuration changes,
  and clear consumed/discarded mailbox references. macOS and iOS Release builds
  pass; runtime validation and memory measurements remain with the user.

- [x] Separate profiling from the control mailbox with bounded atomic recording;
  defer presentation statistics and diagnostic assembly to the UI consumer.
  Concurrent recording and overflow tests pass under Thread Sanitizer; app builds.
- [x] Replace the editor control mailbox condition lock with atomic latest-value
  handoffs and a spinning render-worker wait. Coalescing preserves pending
  controls; UI publication never waits. Seven focused tests pass under Thread
  Sanitizer and the app builds; manual playback/input validation remains pending.

- [x] Add the document colour picker with correct display-encoded to linear input
  conversion and live updates that do not recreate the system unnecessarily.
- [ ] Add an editor-only diagnostic driven by the production colour pipeline.
- [ ] Compare correct linear interpolation with an intentionally incorrect
  gamma-space reference.
- [ ] Visualize premultiplied-alpha overlap, HDR intensity, stored linear colour,
  pre-tone-map output, and final display encoding.
- [ ] Extend with bloom comparisons when bloom enters scope.

## 3. Emitters, Lifetime, and Properties

- [x] Introduce isolated authored, compiled, and running emitter boundaries,
  including deterministic layout compilation, omitted unused storage, and
  arena reuse across layout-compatible edits.
- [x] Extract the current system-of-one-emitter into a system coordinator with
  emitter-owned arena slices and one or more renderer definitions per emitter.
- Compile authored definitions only when structure changes, not per fixed tick
  or while scrubbing.
- Define birth time, lifetime, normalized age, spawn rate, and alive/dead
  behaviour while preserving deterministic restart, rewind, and seeking.
- [x] Define the isolated collection-backed authored property model, including
  ordered modifiers, composable operations, constants, deterministic random
  values, keyframed interpolation, and life/speed/distance/emitter-time inputs.
- [x] Migrate authored position, velocity, colour, size, and rotation onto typed emitter
  properties with key-path collection access and internally managed stable
  modifier identity; preserve the existing specialized runtime lowering.
- [x] Centralize generic initial-value lowering in `PropertyCompiler`; keep
  property semantics in typed descriptors, then generically aggregate their
  storage requirements and passes without property-specific compiler methods.
- [x] Keep authored effect presets out of `PixlParticles`; seed new editor
  systems from the app-owned `EmitterPreset.debris` definition through the
  public property API.
- Begin property authoring with constants, deterministic ranges, and normalized
  lifetime functions. Derive analytically on GPU whenever possible; materialize
  AoSoA previous/current storage only for stateful or interpolated semantics.
- [x] Add portable synchronous simulation jobs and an Apple-owned persistent
  spinning pool. Keep SIMD integration and parallel spawn calculation batched;
  retain deterministic ID/lifetime bookkeeping on the owning thread.
- [x] Provide all-core and performance-core-count configurations, a serial
  comparison mode, and a configurable batch multiplier (default four).
- [x] Validate exact range coverage, bit-identical simulation, seeking/removal,
  and spawn-rate changes under Thread Sanitizer; macOS app builds.
- [x] Complete matched serial/all-core/performance-core-count benchmark report:
  `Benchmarks/Results/2026-09-22-batched-simulation.md`. Results retained for
  review; no automatic promotion to accepted PERF.md baselines.
- Do not introduce a generic runtime property dictionary or dynamic dispatch in
  hot paths.

## Packed Memory Layout — Awaiting Runtime Validation

- [x] Replace per-particle Float32 RGBA with UInt16 palette indices and a shared
  premultiplied HDR table; update point/billboard and visibility shader bindings.
- [x] Keep Float32 current positions; pack velocity and interpolation displacement
  into signed 10:10:10 words with compiler-derived scales and SIMD decoding.
- [x] Replace per-slot death ticks/links with consecutive-slot birth cohorts and
  wrapping UInt32 expiry ticks, preserving removal/recycling and reset semantics.
- [x] Reach a calculated 32-byte moving / 24-byte stationary slot layout, excluding
  palette, cohort fragmentation, spawn scratch, and allocation rounding.
- [ ] User runtime validation: playback/seek/recycle, visual precision, serial and
  parallel equivalence, and memory measurements. No performance baseline promoted.
- [ ] Measure explicit-removal cost and cohort fragmentation before extending
  scheduling to high-volume arbitrary event-driven removal.

## Later

- Make toolbar undo/redo availability observe `UndoManager` changes immediately;
  document edits already register and execute correctly.
- Analytic collisions and response semantics, then measured spatial
  partitioning.
- Niagara-style events and explicit payloads, including collision-driven events.
- Distance/projected-coverage billboard LOD after the baseline is measured.
- Finder thumbnails and Quick Look playback.
- Disk-backed editor checkpoints if workloads justify them.

## Dense Point GPU Optimization — Implemented, Editor Validation Pending

- [x] Measure hardware reference and automatic production path sequentially.
- [x] Add compute rasterization for dense opaque points with automatic capability
  and transparency fallback; no application switch.
- [x] Verify multi-colour, perspective, odd-size, sparse and transparent output.
- [x] Compile the macOS editor and run the isolated renderer regression tests.
- [ ] User measurement and visual confirmation in the editor. Provisional local
  results live in `Benchmarks/Renderer/Metal/RESULTS-2026-09-25.md`; do not promote
  them to accepted `PERF.md` results yet.

Full package tests currently fail to compile because legacy particle tests still
call the removed `System(particleCount:)` initializer; unchanged by this work.

## Shared Billboard GPU Optimization — Implemented, Editor Validation Pending

- [x] Replace the point-only compute pass with shared point/billboard projection,
  coverage and ordered geometry submission; no application switch.
- [x] Preserve translucent blending and depth-write semantics, including zero
  alpha and equal-depth ordering. Translucent speed is effectively unchanged.
- [x] Bound large-footprint compute work using GPU indirect geometry fallback.
- [x] Pass 47 GPU image comparisons, seven isolated renderer tests and the macOS
  Release build. Cover resize, near-plane, opacity transitions and all billboard
  sizing/facing modes.
- [x] Measure both shapes and opaque/translucent workloads sequentially. Reject
  slower tile-list, mesh and oversized-triangle experiments.
- [ ] User editor validation. Provisional timings live in
  `Benchmarks/Renderer/Metal/RESULTS-2026-09-25-billboards.md`; accepted `PERF.md`
  baselines remain unchanged.

## Compute Preparation Tuning — 2026-09-25

- [x] Record user-confirmed eight-million-particle editor results in PERF.md.
- [x] Benchmark compute-only alternatives with image validation and clean builds.
- [x] Retain only the existing 128-thread limit declaration; paired total GPU
  medians improve about 5%, without demonstrated p95 improvement.
- [x] Remove slower or inconclusive coverage-lane, depth-phase, loop-flattening,
  smaller-group and unrolling experiments.
- [x] Prevent stale optimized Swift callers in the benchmark build workflow.
- [ ] User validation of this small tuning change; standalone results remain
  provisional in `Benchmarks/Renderer/Metal/RESULTS-2026-09-25-compute.md`.
- [ ] Finer shader profiling before further algorithm or scratch-storage changes.


## Dense Billboard Zoom and Diagnostics — 2026-09-25

- [x] Fuse sampled visibility counts into existing coverage; user confirms the
  separate Diagnostics stage is essentially free. Keep GPU timestamps per frame.
- [x] Reproduce the enlarged-billboard whole-batch geometry memory/time cliff.
- [x] Add seeded depth rejection, index compaction and cooperative refinement
  within the shared raster pass, without an application switch.
- [x] Preserve normal-size performance and pass 57 image / 76 visibility checks,
  seven renderer unit tests, and the macOS Release build.
- [x] Extend the renderer harness with size/zoom controls and process/Metal memory.
- [ ] User editor validation of refinement; matched harness results are provisional
  in `Benchmarks/Renderer/Metal/RESULTS-2026-09-25-zoom.md`.
- [ ] Extreme footprints above 4096 pixels still use ordered geometry; transparent
  batches retain their existing compositing costs.

## Paused Editor CPU — 2026-09-25

- [x] Reproduce empty-mailbox and idle-simulation-pool CPU spinning independently.
- [x] Park the render worker while paused and park simulation workers between
  paused operations; preserve active playback polling and atomic job dispatch.
- [x] Wake for control changes, rendering, seeking, resume and shutdown, with
  coalesced mailbox notifications and no per-frame wake-token accumulation.
- [x] Pass focused mailbox and simulation tests, including idle CPU regression,
  repeated wake/suspend cycles and deterministic simulation; iOS Release builds.
- [ ] User iPad validation: paused CPU/power, edits and camera navigation, seek,
  resume and document closure. Local idle probes are not accepted device baselines.
- [ ] Design deferred per-thread timeline capture over the editor to investigate
  the user's negligible serial-versus-performance-core-count improvement.

## Timeline Profiler — 2026-09-25

- [x] Add reusable `PixlProfiler` / `PixlProfilerUI` products with static metadata,
  preallocated recording, bounded histories and deferred processing.
- [x] Integrate editor CPU/thread and GPU timeline hooks, frame selection,
  automatic tick-duration scaling, expandable tracks and inclusive timing statistics.
- [x] Freeze on pause; retain late GPU submissions and reject stale generations.
  Preserve paused sleeping and cancel repeating profiler work while frozen.
- [x] Validate concurrency and worker integration with Thread Sanitizer, inspect
  the rendered viewer, and verify actual Metal intervals against stage counters.
- [x] Add a release recording allocation probe with a positive control. Local
  runs observed zero recording allocations and roughly 70–80 ns per completed
  scope; not promoted to accepted device performance baselines.
- [ ] iPad validation: capture/inspection, screenshot readability, end-to-end
  profiling overhead and serial/performance-core workload comparison.
- [ ] Add deeper serial simulation-phase scopes and separate CPU resource/drawable
  waits if these first traces show that more detail is needed.
