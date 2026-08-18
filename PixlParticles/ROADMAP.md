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
- Extract the current system-of-one-emitter into a system coordinator with
  emitter-owned arena slices and one or more renderer definitions per emitter.
- Compile authored definitions only when structure changes, not per fixed tick
  or while scrubbing.
- Define birth time, lifetime, normalized age, spawn rate, and alive/dead
  behaviour while preserving deterministic restart, rewind, and seeking.
- Begin property authoring with constants, deterministic ranges, and normalized
  lifetime functions. Derive analytically on GPU whenever possible; materialize
  AoSoA previous/current storage only for stateful or interpolated semantics.
- Keep specialized dense passes serial initially, shaped so PixlConcurrency can
  later schedule independent groups without reorganizing data.
- Do not introduce a generic runtime property dictionary or dynamic dispatch in
  hot paths.

## Later

- Make toolbar undo/redo availability observe `UndoManager` changes immediately;
  document edits already register and execute correctly.
- Analytic collisions and response semantics, then measured spatial
  partitioning.
- Niagara-style events and explicit payloads, including collision-driven events.
- Distance/projected-coverage billboard LOD after the baseline is measured.
- Finder thumbnails and Quick Look playback.
- Disk-backed editor checkpoints if workloads justify them.
