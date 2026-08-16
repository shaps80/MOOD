# PixlParticles Roadmap

Work through one decision at a time. Keep the current scope limited to a fast,
point-primitive rendering path.

## 1. Portable Render Data

- Decide the package target boundary and name for renderer-facing data lowering.
- Keep this component separate from simulation even if it initially lives in the
  same package and depends directly on `PixlParticles`.
- Lower interpolated particle values into the smallest fixed packed form that a
  platform renderer can consume with minimal additional work.
- Support point primitives only: one physical framebuffer pixel, colour, and
  opacity. Do not introduce quad, sprite, texture, or variable-size concerns.
- Define buffer ownership so platform renderers can avoid redundant allocation
  and copying.
- Add standalone release benchmarks for interpolation and render-data packing,
  separate from simulation and GPU rendering measurements.

## 2. Metal Renderer

- Add an Apple-platform renderer target to the `PixlParticles` package for iOS,
  macOS, and visionOS.
- Consume the portable packed representation and render Metal point primitives.
- Perform camera projection and fixed-pipeline clipping and depth testing on the
  GPU.
- Replace the SwiftUI Canvas particle drawing path while retaining the existing
  editor camera and controls.
- Measure CPU submission and GPU rendering separately from simulation and
  portable render-data packing.
- Keep this renderer isolated from Pixl integration. Decide how it later shares
  Pixl's Metal device and command workflow only when that integration begins.

## Later

- Collisions.
- Niagara-style events and event payloads, including collision-driven events.

Emitters, quads, sprites, textures, post-processing, additional particle
properties, GPU compute, and advanced culling are deliberately outside the
current roadmap.
