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
- The editor currently renders through SwiftUI Canvas as a diagnostic surface.
  It has renderer-owned perspective, isometric, and front cameras; a projected
  ground plane; perspective orbit controls; and pinch or scroll zoom. Camera
  orientation and zoom are restored per scene.
- Editor controls currently recreate the system from duration, particle count,
  seed, spawn region, and supported spawn domain selections.

## Boundaries

- `PixlParticles` imports no Apple frameworks and must remain usable on
  non-Apple platforms.
- `PixlParticlesUI` imports `PixlParticles` and supports iOS, macOS, and visionOS.
- Simulation, renderer-facing data lowering, and platform drawing are separate
  concerns. Renderer-side code owns buffer packing; platform targets own GPU
  resources and draw submission.
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

## Working Method

- Discuss and resolve one architectural decision at a time.
- Stay concise and focused; expand deeply only when asked.
- Do not introduce new architectural decisions during implementation.
