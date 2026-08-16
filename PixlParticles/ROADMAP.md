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
- Restore the ground plane as a separate editor render pass.
- Measure CPU submission and GPU rendering separately from simulation and
  portable render-data packing.
- Profile Metal culling and drawing independently; accepted CPU scaling shows
  simulation plus position-pair lowering consumes only about 1.46 ms per
  rendered frame at 2 million particles with 30 Hz simulation and 60 Hz
  rendering.
- Validate GPU-only screen-space LOD visually and with Metal traces across the
  activation boundary, dense and sparse tiles, camera motion, and the exact
  maximum-visible ceiling. Tune defaults only from those results.
- Move simulation sampling, renderer lowering, culling, and Metal submission
  under dedicated serial render ownership. Keep `PixlRenderer` synchronous and
  nonisolated; the UI sends immutable settings and replacement commands rather
  than mutating render-owned state.
- After both changes, capture a matched 6-million-particle Metal trace with LOD
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

## Later

- Collisions.
- Niagara-style events and event payloads, including collision-driven events.

Emitters, quads, sprites, textures, post-processing, and additional particle
properties are deliberately outside the current roadmap. Distance LOD remains
later work after the screen-space density path is measured.
