# PixlParticles Roadmap

Work through one decision at a time. Keep the current scope limited to a fast,
point-primitive rendering path.

## 1. Point Colour

- Introduce particle colour without weakening the existing position hot path.
- Lower premultiplied linear HDR colour into the portable `RGBA16Float` layout.
- Decide interleaved versus parallel position/colour buffers through isolated
  measurements once the real lowering paths exist.
- Add standalone release benchmarks for interpolation and render-data packing,
  separate from simulation and GPU rendering measurements.

## 2. Complete the Metal Point Path

- Validate stable GPU frustum compaction across empty, partial, and fully visible
  systems and measure its compute cost against the indirect-draw savings.
- Expose visible-particle counts and Metal stage timings for diagnostics without
  adding CPU readback to the production frame loop.
- Consume packed particle colour in the point shader.
- Keep colour linear and premultiplied through HDR shading and blending, then
  encode only for final display presentation.
- Measure CPU submission and GPU rendering separately from simulation and
  portable render-data packing.
- Profile Metal culling and drawing independently; accepted CPU scaling shows
  simulation plus position-pair lowering consumes only about 1.46 ms per
  rendered frame at 2 million particles with 30 Hz simulation and 60 Hz
  rendering.
- Validate GPU-only screen-space LOD visually and with Metal traces across the
  activation boundary, dense and sparse tiles, camera motion, and the exact
  maximum-visible ceiling. Tune defaults only from those results.
- Validate dedicated serial render ownership during playback, camera input,
  pausing, scrubbing, and system replacement. Confirm the main actor no longer
  performs simulation, lowering, culling, or Metal submission.
- After validation, capture a matched 6-million-particle Metal trace with LOD
  enabled and a 2-million visible ceiling. Compare frame cadence, aggregate
  compute/draw medians and p95, drawable waits, and steady/peak Metal memory
  against the recorded pre-optimization trace.

## 3. Colour Diagnostics

- Add an editor-only diagnostic view driven by the production colour pipeline.
- Compare correct linear interpolation with an intentionally incorrect
  gamma-space reference.
- Visualize premultiplied-alpha overlap on contrasting backgrounds.
- Show an HDR intensity ladder and expose stored linear colour, pre-tone-map HDR
  output, and final display-encoded values through a pixel inspector or GPU
  readback.
- Keep the diagnostic isolated enough to inform a later Pixl equivalent without
  making that integration a current design constraint.
- Extend the diagnostic with bloom comparisons when bloom enters scope.

## Deferred

- Finder thumbnails and Quick Look playback for particle-effect documents.
- Distance LOD after the screen-space density path is measured.
- Niagara-style events and explicit event payloads, including collision-driven
  events once collision semantics exist.

## Planned Expansion

Do not begin this work until the current point-rendering roadmap is reconciled
and its remaining validation is complete.

### 1. Particle Lifetime and Fixed Properties

- Define per-particle birth time, lifetime, normalized age, and alive/dead
  behaviour.
- Preserve deterministic restart, rewind, seeking, and inspection semantics.
- Establish Swift authoring APIs for fixed semantic properties, beginning with
  constants, deterministic ranges, and values evolving over normalized
  lifetime.
- Add properties one at a time and validate their authoring semantics, AoSoA
  storage, specialized whole-buffer passes, interpolation, lowering, and
  performance end to end.
- Keep public particles independent of internal storage. Do not introduce a
  generic runtime property dictionary or dynamic dispatch in hot paths.

### 2. Quad Rendering

- Retain point primitives and add coloured quads as a separate rendering path.
- Add camera-facing billboards alongside ordinary oriented quads.
- Keep quad expansion, camera-facing transforms, packing, culling policy, and
  draw submission in renderer and UI layers. Simulation owns only authored
  particle values required by those renderers, such as size and rotation.

### 3. Collisions

- Resolve collision semantics through small reference implementations before
  committing them to production architecture.
- Begin with analytic collision shapes and response behaviour before mesh or
  scene collision.
- Treat spatial partitioning as a measured performance decision, informed by
  fast reference implementations such as Box2D or Box3D rather than assumed up
  front.

Emitters, sprites, textures, and post-processing remain outside the current
roadmap until explicitly brought into scope.
