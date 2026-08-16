# PixlParticles Context

## Scope

`PixlParticles` is a platform-agnostic particle-system design. `PixlParticlesUI` is its Apple-platform editor for iOS, macOS, and visionOS. These documents cover both projects independently of Pixl's root project documents.

## Goals

- Keep particles and editor scene framing 3D.
- Offer expressive, composable Swift authoring types, then lower them into a runtime representation suitable for hot loops and GPU execution.
- Keep simulation, portable render-data preparation, and platform rendering
  independently measurable and optimizable.
- Make point primitives the first rendering path: one physical framebuffer
  pixel with colour and opacity.

## Foundational Constraints

- Treat a particle effect as a deterministic program over time, not merely mutable emitters updated each frame. It must support pausing, seeking, scrubbing, repeatable tests, and precise state inspection.
- Support Niagara-style events as a core system capability, allowing causal communication between emitters through explicit triggers and event payloads.
- Keep the colour workflow linear throughout authoring conversion, simulation,
  interpolation, shading, blending, HDR rendering, and post-processing. Convert
  from encoded display colour at input boundaries and encode for display only at
  final presentation.
- Prefer premultiplied alpha for colour storage, interpolation, and blending.
  Premultiply RGB only after conversion to linear space. Straight-alpha or
  additive paths must be explicit effect-specific choices.
- Represent renderer-facing per-particle colour as linear HDR `RGBA16Float`.
  RGB may exceed `1`; alpha normally remains within `0...1`.

## Evidence

- Production CPU state is lowered into unsafe property buffers containing
  four-particle SIMD batches. A three-component batch stores `x`, `y`, and `z`
  as `SIMD4<Float>`, with lanes representing particles. This AoSoA layout more
  than halved the measured linear-update cost while preserving exact checksums.
- A public particle remains a complete, renderer-independent snapshot. Internal
  batching must not leak a meaningless fourth spatial component into that API.
- Whole-buffer specialized passes are the default execution shape. Temporary
  measurements found no useful gain from fused rich-property loops or cache
  chunking, while explicit cross-particle SIMD produced the material gain.
- Initial rewind state retains only mutable values required to restore the
  simulation. At present that is initial position; identifiers and velocities
  remain immutable.
- Deterministic spawning currently supports point and line regions plus box and
  sphere regions. Box and sphere support volume and surface domains. Region
  sampling uses stable particle addresses and dedicated random channels so
  unrelated future properties do not perturb existing output.
- Philox4x32-10, integer-to-float mappings, and deterministic trigonometric
  functions are isolated and covered by stable bit-pattern tests. The math
  implementation is intentionally kept movable so it can later become shared
  cross-platform math infrastructure.
- The editor renders point primitives through `PixlMetal` in an `MTKView`. It
  retains perspective, isometric, and front cameras; perspective orbit controls;
  and pinch or scroll zoom. Camera orientation and zoom are restored per scene.
  The former Canvas ground plane is intentionally absent until it becomes an
  editor Metal pass.
- Renderer-facing binary16 colour components use portable `UInt16` bit storage.
  Swift `Float16` is unavailable when compiling for Intel macOS, while the byte
  representation consumed by Metal remains `RGBA16Float`.
- Editor controls currently recreate the system from duration, particle count,
  seed, spawn region, and supported spawn domain selections.

## Boundaries

- Data and control move downstream: `PixlParticles` drives `PixlRenderer`;
  `PixlRenderer` defines rendering, packing, GPU pipelines, culling, and the
  platform contract; `PixlMetal` only implements that contract with Metal.
- `PixlMetal` must never import `PixlParticles` or accept `System`, particles,
  packed particle types, or renderer passes. It translates generic buffers,
  pipelines, encoders, targets, and submission into Metal operations.
- `PixlParticles` and `PixlRenderer` import no Apple frameworks and must remain
  usable on non-Apple platforms. `PixlRenderer` also imports neither Dispatch
  nor Swift Concurrency; platform frame synchronization belongs to adapters.
- The high-level `PixlRenderer.Backend` seam remains independent of GPU APIs.
  A software renderer such as SwiftUI Canvas can implement it directly;
  GPU-backed rendering composes it with the lower-level platform contract.
- The temporary Metal composition is `PixlParticles.Renderer` →
  `PixlRenderer.GPUBackend` → `PixlMetal.Platform`. Future Pixl integration
  replaces only the final adapter with `PixlPlatform`.
- `PixlParticlesUI` imports `PixlParticles` and supports iOS, macOS, and visionOS.
- Simulation, renderer-facing data lowering, and platform drawing are separate
  concerns. Renderer-side code owns buffer packing and rendering policy;
  platform targets own concrete GPU resources and command translation.
- Metal visibility uses stable GPU compaction: block-local scans, deterministic
  block offsets, stable index scatter, and indirect drawing. Culling never
  mutates authoritative simulation or changes particle order.
- High-density point rendering will use optional screen-space LOD after frustum
  compaction. The GPU-visible count selects the path without CPU readback.
  Below the activation threshold, the existing visible-index buffer is drawn;
  above it, particles are counted in quantized screen tiles and thinned using a
  stable particle-ID hash. Do not use atomic arrival order for selection.
- Screen-space LOD defaults are 16-by-16 physical-pixel tiles, one retained
  point per pixel, activation at 500,000 visible points, and an exact 1
  million visible-point ceiling. These deliberately low initial thresholds
  make the LOD path easy to exercise and inspect in the editor. Distance LOD remains a separate future
  artistic control; the maximum-visible ceiling is a safety limit, not a
  replacement for authored particle count.
- LOD resources must remain parallel and optional. Allocate no LOD-specific
  storage when the feature is disabled or total particle count cannot reach the
  activation threshold. Reuse existing scan scratch after frustum compaction
  where possible. A stable-ID GPU buffer and final compacted index buffer may
  add particle-proportional storage only on the high-density path.
- Acquire the MTKView render-pass descriptor and drawable as late as possible,
  after buffer availability, position-pair lowering, and culling encoding.
  Early acquisition caused double-buffer back-pressure despite sufficient GPU
  execution budget.
- Camera state, projection, ground-plane visualization, input gestures, and
  scene restoration belong to `PixlParticlesUI`; none are particle simulation
  responsibilities.
- Pixl renderer improvements may be identified, but particle-system design must not change Pixl implicitly.
- Tests use Swift Testing. XCTest is reserved for performance tests. UI testing is manual only.
- Never run the app; build it and run valuable non-UI tests only.
- Backward seeking currently restores initial state and deterministically
  replays forward. This is correct but not scalable for long effects; periodic
  checkpoints are the intended next direction. Checkpoint frequency and memory
  policy remain undecided.
- Editor LOD controls use ordinary local defaults and are deliberately not
  persisted through `SceneStorage`.

## Working Method

- Discuss and resolve one architectural decision at a time.
- Stay concise and focused; expand deeply only when asked.
- Do not introduce new architectural decisions during implementation.
