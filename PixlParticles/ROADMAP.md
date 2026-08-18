# PixlParticles Roadmap

Work through one decision at a time. Keep the current scope limited to a fast,
point-primitive rendering path.

## 1. Colour Diagnostics

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
- Disk-backed editor checkpoints; current workloads do not justify them.

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

### 4. Events

- Add Niagara-style events and explicit event payloads as a core system
  capability.
- Include collision-driven events once collision semantics exist.
- Keep this work late in the planned expansion, after particle lifetime, fixed
  properties, quad rendering, and collision semantics are established.

Emitters are now the next active design stream. Sprites, textures, and
post-processing remain outside the current roadmap until explicitly brought
into scope.
