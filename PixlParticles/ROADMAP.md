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
- Add configurable screen-space point LOD, initially defaulting to 16-by-16
  physical-pixel tiles and one retained point per pixel.
- Select the LOD path entirely on the GPU from the frustum-visible count. Keep
  the current path when below 500,000 visible points; above it, count tile
  density, deterministically retain particles by stable ID, compact them, and
  enforce an exact 1 million visible-point ceiling. These initial thresholds
  intentionally favor editor testing and can be tuned from measured evidence.
- Add stable IDs as a parallel renderer buffer only when the LOD path can
  activate. Reuse existing culling scratch and avoid LOD allocation entirely
  for disabled or guaranteed-low-count systems.
- Expose non-persisted editor controls for activation count, tile size, target
  points per pixel, and maximum visible points.

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
