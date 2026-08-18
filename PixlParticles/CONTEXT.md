# PixlParticles Context

## Scope

`PixlParticles` is a platform-agnostic particle-system design. `PixlParticlesUI` is its Apple-platform editor for iOS, macOS, and visionOS. These documents cover both projects independently of Pixl's root project documents.

## Goals

- Keep particles and editor scene framing 3D.
- Offer expressive, composable Swift authoring types, then lower them into a runtime representation suitable for hot loops and GPU execution.
- Keep simulation, portable render-data preparation, and platform rendering
  independently measurable and optimizable.
- Retain point primitives as a one-physical-pixel path, and add renderer-selected
  billboard quads without making simulation renderer-aware.

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
- Philox4x32-10 and integer-to-float mappings remain particle-owned.
  Deterministic generic trigonometry now lives in the standalone `PixlMath`
  package and retains the same stable Float and Double bit-pattern tests.
- The editor renders point primitives through `PixlMetal` in an `MTKView`. It
  retains perspective, isometric, and front cameras; perspective orbit controls;
  and pinch or scroll zoom. Perspective orbit accumulates and persists a
  quaternion rather than yaw/pitch, allowing continuous rotation through the
  poles. Camera orientation and zoom are restored per scene.
  Portable camera/navigation state and diagnostic descriptions live in
  `PixlEditorSupport`; Apple gesture translation and persistence remain UI-owned.
- Renderer-facing binary16 colour components use portable `UInt16` bit storage.
  Swift `Float16` is unavailable when compiling for Intel macOS, while the byte
  representation consumed by Metal remains `RGBA16Float`.
- Editor controls recreate the system only for authored simulation inputs such
  as particle count, seed, colour, and spawn region. Renderer selection and
  billboard values flow live without restarting or seeking the simulation.

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
- The production Metal composition is `PixlParticles.Renderer` →
  `PixlRenderer.DeviceBackend` → `PixlMetal.Platform`. It specializes an empty
  concrete render composition, introducing no editor allocation, branch,
  resource, pipeline, or draw. The editor instead uses
  `ComposedDeviceBackend<PixlEditorSupport.Renderer>` and the same command
  buffer, render target, and render encoder.
- `PixlEditorSupport` is platform-agnostic. `PixlEditorSupportMetal` contains
  only its Metal shader library and wraps `PixlMetal.Platform` for pipeline
  lookup; PixlMetal still creates every buffer, pipeline, encoder, and target.
  Excluding both editor products excludes all editor code and shader resources.
- `PixlParticlesUI` imports `PixlParticles` and supports iOS, macOS, and visionOS.
- Simulation state and platform drawing remain separate concerns. Render-facing
  particle state uses the simulation's authoritative four-particle AoSoA layout
  inside aligned `PixlRenderer.HostBuffer` storage. Renderer code defines that
  portable storage contract and rendering policy; platform targets wrap it in
  concrete GPU resources and own command translation. Metal uses no-copy shared
  buffers and indexes particle batch/lane directly in shaders. Position history
  swaps the roles of two existing buffers after integration rather than copying
  current state into previous state. Point colour is currently immutable and
  occupies one shared buffer, so it has no CPU history or shader interpolation.
- The current document owns one standalone `ParticleRenderer` definition. The
  definition selects point or billboard rendering and holds renderer-only
  billboard settings; fixed size and rotation remain semantic particle values
  lowered into one per-draw constant block. They are not repeated in particle
  storage. This is the initial shape for a future emitter to expose multiple
  renderers over one shared simulation.
- `PixlParticles` provides no authored effect presets. Bare emitter properties
  lower from neutral identities only. `PixlParticlesUI` owns the initial
  `EmitterPreset.debris` starting point and translates the document's current
  flattened controls into that authored emitter at the app composition boundary.
- `System` coordinates one authored `Emitter`, its internal deterministic
  `CompiledEmitter`, and a mutable `EmitterInstance` owning an arena slice.
  Emitters expose typed, key-path-addressed position, velocity, colour, size,
  and rotation properties as ordered modifier collections. Modifier identity is assigned
  internally on insertion and retained through document coding and replacement.
  Spawn region remains emitter configuration; position modifiers operate on its
  eventual sampled result. Compilation currently lowers the existing constant
  colour and stationary or deterministic uniform half-open velocity forms, omits
  stationary velocity/history storage and its integration pass, and introduces
  no generic property dispatch into the fixed-tick hot loop. Current constant
  size and rotation still lower into the existing per-draw GPU constants. One
  generic `PropertyCompiler` handles authored initial-value shape for every
  typed property. Typed descriptors declare semantic validation, storage
  requirements, and required passes. Emitter compilation generically aggregates
  those effects; it contains no property-specific lowering methods.
- Billboard rendering expands four procedural vertices per compacted visible
  particle and submits one indirect triangle-strip draw. It adds no geometry or
  index buffer. Size is a two-component value, rotation is one radian scalar,
  and world or physical-pixel size spaces are selected per renderer. Camera,
  camera-plane, and camera-position/world-up facing modes are GPU evaluated from
  one compact camera frame supplied per draw.
- Metal visibility uses stable GPU compaction: block-local scans, deterministic
  block offsets, stable index scatter, and indirect drawing. Culling never
  mutates authoritative simulation or changes particle order.
- Point and billboard rendering share one visibility kernel and compacted-index
  arena. Point visibility tests particle centres. World-space billboards use a
  conservative half-diagonal bounding sphere; screen-space billboards expand
  clip tests by their physical-pixel radius. Authored cubic bounds deliberately
  remain centre-based. Point LOD is bypassed for billboards without allocating
  or retaining LOD resources.
- Optional authored cubic bounds are fused into the existing GPU visibility
  classification. Particles outside the cube remain simulated but are omitted
  from rendering. Its editor visualization is a generic instanced `WireBox`.
  Wire boxes and frustum edges share one 24-vertex procedural wire-volume draw.
  The cube is anchored to the ground plane at Y -100 and grows upward as its
  scale changes.
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
  Metal resources, culling, and submission. Its latest-value mailbox
  uses `NSCondition`, never queues stale frames, and introduces no concurrency
  dependency into `PixlRenderer`.
- Acquire the MTKView render-pass descriptor and drawable as late as possible,
  after buffer availability and culling encoding.
  Early acquisition caused double-buffer back-pressure despite sufficient GPU
  execution budget.
- Portable editor cameras, navigation, diagnostic values, and render
  composition belong to `PixlEditorSupport`; none are particle simulation or
  production renderer responsibilities. `PixlParticlesUI` owns gesture
  translation and scene restoration. Ground-plane lines and frustum rays share
  one procedural guide draw; wire boxes and frustum edges share one instanced
  wire-volume draw. Hidden diagnostics encode zero draws.
- Perspective frustum inspection keeps the scene camera frozen for culling,
  LOD, and every other scene decision while a separately persisted
  `observerCamera` controls presentation. Enabling and disabling inspection
  ease between the scene and observer poses; first use pulls the observer back
  slightly so the frustum is immediately visible. Gestures interrupt the
  transition directly.
- Debug rendering must have zero impact when editor products are excluded and
  effectively zero impact while linked but hidden. It is procedural, performs
  no steady-state allocation or readback, encodes no hidden work, and batches
  by primitive category rather than object count. `PixlRenderer` owns only the
  generic composition seam and instanced draw command.
- Pixl renderer improvements may be identified, but particle-system design must not change Pixl implicitly.
- Tests use Swift Testing. XCTest is reserved for performance tests. UI testing is manual only.
- Never run the app; build it and run valuable non-UI tests only.
- Backward seeking restores retained initial state when configured, otherwise
  regenerates initial particles deterministically and replays forward. The
  editor disables retained rewind state by default. Disk-backed editor
  checkpoints are deliberately deferred: present team workloads do not justify
  their complexity.
- Per-window editor preferences are one Codable `EditorSettings` value persisted
  through `SceneStorage`: camera preset/orientation/target/zoom, ground-plane,
  inspector and timeline visibility, inspector placement, and playback mode.
  Stored JSON is merged over current defaults before decoding so newly added
  preferences do not invalidate older scenes.
- Authored particle configuration is not editor preference state. Duration,
  particle count, seed, spawn configuration, LOD, and culling bounds belong in
  the particle-effect document. The editor uses the modern snapshot-based
  `Document`, `ReadableDocument`, `WritableDocument`, and `DocumentGroup` shape
  already validated by Comix. Native `.pixlparticles` JSON files support
  Files/Finder and iCloud Drive workflows. Document mutations register undo and
  redo through the shared `performEdit` path.
- The leading View menu toggles the ground plane, inspector, timeline, and
  authored culling bounds. Enabling culling
  bounds reveals a 1-to-10,000 scale field; the initial scale is 500.
- Playback uses a primary-action menu beside the timeline slider. Play stops at
  the end and restarts from zero when invoked again; Loop resets through the
  render-thread seek mailbox and continues. Toolbar primary actions expose
  document undo and redo.

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
- CPU renderer handoff is now constant-time and directly shares authoritative
  AoSoA storage with the GPU. The former per-tick position, colour, and ID
  lowering buffers are gone; `FrameBuffers` retains only culling and optional
  LOD scratch. No additional in-flight source storage has been introduced.
- Position integration now writes the next state into the old previous buffer
  and swaps roles. Fixed point colour uses one buffer. Native fixed-update
  medians fell from 1.007 to 0.483 ms at one million particles and from 2.074 to
  0.877 ms at two million, with unchanged deterministic checksums.
- Dedicated render ownership is validated across playback, camera input,
  pausing, backward and forward scrubbing, and system replacement.
- The final matched 6-million-particle trace sustained the 60 Hz submission
  tier with 5.958 ms median and 8.550 ms p95 effective GPU work. Renderer
  validation is complete. Direct shared-source lifetime and synchronization
  are also validated on iPad without additional in-flight source storage.
- The initial billboard path, both size spaces, three facing modes, document
  persistence, and live inspector editing compile across the macOS app and its
  Metal shader library. Visual validation and point-versus-billboard performance
  measurements remain pending; no billboard benchmark is accepted yet.
- `System` now coordinates one compiled `EmitterInstance`. The public legacy
  initializer lowers to an authored `Emitter` and remains bit-identical. A
  system-owned `ParticleArena` supplies an `EmitterArenaSlice`; with one emitter
  that slice spans the arena. Moving emitters retain the established AoSoA
  position/velocity hot path, while stationary emitters omit velocity and
  previous-position storage. This is the extraction seam for multiple emitter
  slices without changing the public simulation model again.
- The isolated authored property model is `Property<Value>`, an ordered mutable
  random-access collection of namespaced `Property<Value>.Modifier` values.
  Each modifier has a stable portable `UInt64` ID, an operation, a typed value,
  and optional `variesWith` input. Values support constants, deterministic
  proportional or per-value random ranges, and keyframed curves whose individual
  values may also be random. Keyframe interpolation supports step, linear,
  ease-in, ease-out, and ease-in-out. Life, bounded speed, referenced distance,
  total emitter age, and normalized emitter-loop inputs are authored explicitly.
  The complete model is Codable document data and currently has no runtime,
  storage, simulation-loop, or GPU integration.
