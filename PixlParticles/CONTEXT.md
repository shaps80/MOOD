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
- A zero duration means the system runs forever. Positive durations remain
  finite and reset according to the editor's Play or Loop mode.
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
- Deterministic spawning currently supports point and line regions plus cube and
  sphere regions. Cube and sphere support volume and surface domains. Region
  sampling uses stable particle addresses and dedicated random channels so
  unrelated future properties do not perturb existing output.
- Philox4x32-10, integer-to-float mappings, and deterministic trigonometric
  functions are isolated and covered by stable bit-pattern tests. The math
  implementation is intentionally kept movable so it can later become shared
  cross-platform math infrastructure.
- The editor renders point primitives through `PixlMetal` in an `MTKView`. It
  retains perspective, isometric, and front cameras; perspective orbit controls;
  and pinch or scroll zoom. Perspective orbit accumulates and persists a
  quaternion rather than yaw/pitch, allowing continuous rotation through the
  poles. Camera orientation and zoom are restored per scene.
  Its ground plane is an editor pass composed before particles in the shared
  render encoder.
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
  `PixlRenderer.DeviceBackend` → `PixlMetal.Platform`. Future Pixl integration
  replaces only the final adapter with `PixlPlatform`.
- `PixlParticlesUI` imports `PixlParticles` and supports iOS, macOS, and visionOS.
- Simulation, renderer-facing data lowering, and platform drawing are separate
  concerns. Renderer-side code owns buffer packing and rendering policy;
  platform targets own concrete GPU resources and command translation.
- Metal visibility uses stable GPU compaction: block-local scans, deterministic
  block offsets, stable index scatter, and indirect drawing. Culling never
  mutates authoritative simulation or changes particle order.
- Optional authored cubic bounds are fused into the existing GPU visibility
  classification. Particles outside the cube remain simulated but are omitted
  from rendering. The matching editor visualization is one procedural line
  draw containing 12 edges and no geometry buffer; later multiple bounds can
  retain that 24-vertex shape and use instancing. The cube is anchored to the
  ground plane at Y -100 and grows upward as its scale changes.
- High-density point rendering uses optional screen-space LOD after frustum
  compaction. The GPU-visible count selects the path without CPU readback.
  Below the activation threshold, the existing visible-index buffer is drawn;
  at or above it, particles are counted in quantized screen tiles and thinned
  using a stable 32-bit hash derived from each 64-bit particle ID. Selection uses integer thresholds,
  stable compaction order, and an exact upper bound on the indirect draw count;
  it never depends on atomic arrival order.
- Screen-space LOD defaults are 16-by-16 physical-pixel tiles, one retained
  point per pixel, activation at 500,000 visible points, and an exact 1
  million visible-point ceiling. These deliberately low initial thresholds
  make the LOD path easy to exercise and inspect in the editor. Distance LOD remains a separate future
  artistic control; the maximum-visible ceiling is a safety limit, not a
  replacement for authored particle count.
- LOD resources must remain parallel and optional. Allocate no LOD-specific
  storage when the feature is disabled or total particle count cannot reach the
  activation threshold. The implementation reuses frustum scan scratch, keeps
  one immutable stable-ID buffer, and sizes each final compacted index buffer to
  the configured visible ceiling rather than total particle capacity. Disabling
  LOD or dropping below the total-count activation threshold releases those
  resources.
- Portable particle and renderer code is nonisolated by default. Actor or thread
  ownership belongs at composition boundaries. The editor main actor configures
  `MTKView`; a dedicated serial thread owns simulation sampling, seeking,
  lowering, Metal resources, culling, and submission. Its latest-value mailbox
  uses `NSCondition`, never queues stale frames, and introduces no concurrency
  dependency into `PixlRenderer`.
- Acquire the MTKView render-pass descriptor and drawable as late as possible,
  after buffer availability, position-pair lowering, and culling encoding.
  Early acquisition caused double-buffer back-pressure despite sufficient GPU
  execution budget.
- Camera state, input gestures, and scene restoration belong to
  `PixlParticlesUI`; none are particle simulation responsibilities. Portable
  editor-pass composition and ground-plane rendering belong to `PixlRenderer`.
  The ground plane reproduces the former Canvas visualization using one
  procedural line draw with no geometry buffer: height -100, extent 500,
  spacing 50, and linear grey at 20 percent opacity.
- Pixl renderer improvements may be identified, but particle-system design must not change Pixl implicitly.
- Tests use Swift Testing. XCTest is reserved for performance tests. UI testing is manual only.
- Never run the app; build it and run valuable non-UI tests only.
- Backward seeking restores retained initial state when configured, otherwise
  regenerates initial particles deterministically and replays forward. The
  editor disables retained rewind state by default. Periodic checkpoints remain
  the intended scalable direction for long effects.
- Editor LOD controls use ordinary local defaults. View visibility toggles,
  culling-bounds scale, playback mode, camera orientation, and camera zoom
  persist per scene through `SceneStorage`.
- The leading View menu toggles the ground plane, timeline, and authored
  culling bounds. The inspector remains permanently visible. Enabling culling
  bounds reveals a 1-to-10,000 scale field; the initial scale is 500.
- Playback uses a primary-action menu. Play resets to time zero and pauses on
  completion; Loop resets through the render-thread seek mailbox and continues.

## Working Method

- Discuss and resolve one architectural decision at a time.
- Stay concise and focused; expand deeply only when asked.
- Do not introduce new architectural decisions during implementation.

## Current Checkpoint

- Six million particles remain fully simulated while screen-space LOD limits
  drawing to the configured visible ceiling.
- LOD retains compact particle indices. A measured sequential clip-space
  position experiment increased effective GPU work and Metal memory, so it was
  removed rather than becoming production policy.
- With a 2-million visible ceiling, manual Release testing improved from the
  previous approximately 30 FPS to close to 60 FPS. Process memory fell from
  approximately 1.18 GiB to 960 MiB–1.0 GiB.
- CPU regression measurements remain clean: one-million simulation and lowering
  measured 0.642 ms and 0.778 ms; two-million measured 1.285 ms and 1.547 ms.
- Dedicated render ownership is implemented and awaits manual interaction and
  scrubbing validation. After validation, collect the final matched 6-million
  Metal trace. Do not begin GPU simulation until this renderer sequence is
  measured.
