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
- Per-particle colour uses a `UInt16` palette index. Shared palette entries are
  premultiplied linear HDR `SIMD4<Float>` values; Metal converts the selected
  entry to `half4` for shading. RGB may exceed `1`; alpha remains within `0...1`.

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
- Colour indices are portable `UInt16` values, not binary16 colour components.
  The current compiler produces a one-entry immutable palette for constant
  colour; the buffer format supports up to 65,536 authored entries.
- Each editor document lazily owns one persistent simulation owner, exposing a
  non-optional system to ContentView. View construction and play/pause never
  create replacement systems. Document edits (including undo/redo) normalize
  inputs before comparing seed, spawn rate, lifetime, colour, and spawn region;
  only changed simulation inputs replace the system. Duration, renderer selection,
  and billboard values flow live without restarting or seeking the simulation.
  Latest-value handoffs clear consumed and discarded payloads immediately so
  their slots do not retain obsolete systems.

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
  buffers and indexes particle batch/lane directly in shaders. Current positions
  remain Float32 xyz batches; velocity and interpolation displacement each use
  one 32-bit word per particle (three signed ten-bit components, two reserved
  bits). Per-particle colour is a UInt16 index into an immutable shared palette.
  Packed storage is described below; it supersedes position ping-pong and the
  full per-particle colour buffer.
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
- Without active point LOD, points and billboards read shared simulation buffers
  directly. No per-particle visibility index or scan-offset buffers are allocated.
  Dense opaque draws use shared compute coverage as described below; ordered
  geometry expands billboards into four procedural vertices without a geometry
  buffer. Size, rotation, size space and facing remain per-draw values.
- Direct vertex rejection and optional diagnostic counting share the same
  visibility predicate as LOD compaction: point centres, conservative billboard
  bounds, and authored centre-based cubic bounds. Diagnostics retain one UInt32
  per 256-particle block per in-flight frame; readback slots advance only after
  submission. Culling never changes simulation state or particle order.
- Active point LOD retains stable GPU compaction: block-local scans, block
  offsets, stable index scatter, and indirect draws. Leaving that path releases
  its per-particle scratch and index buffers.
- The Metal adapter caches one immutable indirect draw command, inheriting the
  current pipeline and buffer bindings. Unchanged primitive/counts reuse it;
  changed counts replace it while in-flight submissions retain earlier commands.
  Resources inherited by ICB execution are explicitly declared. Unsupported
  devices or failed ICB allocation use ordinary direct drawing. There is no
  runtime configuration switch. Portable renderers express reusable draw intent
  with an ordinary-draw default implementation.
- The GPU culling arena grows to the exact required capacity and retains small
  reductions. At 25% utilisation or less it rebuilds at the current size,
  releasing substantially oversized visibility storage after a particle-count
  reduction.
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
  Metal resources, culling, and submission. Its latest-value mailbox uses
  preallocated single-producer/single-consumer triple buffers with atomic slot
  exchange. UI snapshots carry per-field revisions so frame coalescing retains
  pending system replacement, seek/reset, and duration changes without replaying
  consumed commands. The reverse channel carries completed playback time and
  persistent failures. Shutdown is a separate atomic flag. The render worker
  spins for publication during active playback, but parks on a coalesced semaphore
  wake when paused or before the first frame. Controls, frames, and shutdown wake
  it without making the UI wait; paused edits still render on demand. No concurrency dependency is introduced
  into `PixlRenderer`. Focused tests run with
  `PixlParticlesUI/.scripts/test-mailbox --sanitize thread`.
- Simulation accepts an optional synchronous `SimulationExecutor`; nil retains
  serial execution. Portable `SimulationJob` values borrow a context for one
  complete dispatch. Position integration partitions whole four-particle SIMD
  batches. Spawn calculations use disjoint preallocated particle outputs; ID
  allocation, birth-cohort ordering, compaction, and storage scatter remain on
  the owning thread. Every dependent phase waits for completed jobs, preserving
  deterministic particle state through reset, recycling, removal, and seeking.
- The Apple UI owns a persistent `SpinningJobPool`, reused across ticks and
  system replacements. The calling render thread participates; total worker
  count includes that caller. Workers claim ranges with an atomic epoch/count/
  index ticket and publish completion atomically. Workers start suspended and
  park on a condition while playback is paused, including after paused seeks.
  Dispatch wakes a suspended pool; active dispatch retains atomic claiming and
  spinning between generations. Worker exit also suspends any executor retained
  by a document system. Completion waits for jobs,
  not acknowledgement from idle workers. Shutdown waits for worker exit before
  releasing shared state. No PixlConcurrency dependency is introduced.
- The default is all physical cores with four batches per worker. Launch
  environment `PIXL_SIMULATION_CORES=performance` sizes the pool to performance
  core count; `all` selects all physical cores and `serial` disables the pool.
  `PIXL_SIMULATION_BATCHES` changes the multiplier (default 4). macOS controls
  actual placement; performance mode is a high-QoS P-core-count experiment, not
  a core-affinity guarantee. Platform discovery and thread creation remain
  UI-owned. The matched standalone harness compiles these exact pool sources.
  Focused correctness tests: `PixlParticlesUI/.scripts/test-simulation-jobs
  --sanitize thread`.
- GPU profiling keeps the existing command-buffer total and uses Metal stage
  timestamp attachments for preparation compute, diagnostic compute, draw-pass
  elapsed time, vertex time, and fragment time. The draw pass includes editor
  guides/overlays; vertex and fragment intervals may overlap and are not additive.
  GPU ticks are calibrated with Metal CPU/GPU reference timestamps. A bounded
  four-lease pool reuses 128-entry sample buffers only after completion/resolution;
  unsupported counters and invalid samples remain unavailable, never zero.
  Registering the timing callback before encoding enables counters only when
  diagnostics are captured. No extra pass boundaries or synchronous GPU waits.
  The panel averages valid samples independently for each row.
  `PixlParticles/.scripts/benchmark-rendering` builds/runs the standalone macOS
  production-Metal benchmark with the same timing fields (median/p95). Its paused
  fixture and serial submissions isolate GPU work; it excludes editor guides.
- Editor profiling is separate from the control mailbox. Render samples, GPU
  durations, and presentation timestamps use preallocated bounded atomic buffers
  supporting concurrent producers and one UI consumer. Recording makes one slot
  claim attempt, never waits or retries, and counts samples dropped when the
  selected slot is occupied. The UI consumer assembles diagnostics, converts
  simulation durations, and calculates presentation-window statistics. GPU frame synchronization remains independent of profiling. Focused profiling tests run with
  `PixlParticlesUI/.scripts/test-profiling --sanitize thread`.
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

## Packed Simulation Storage — 2026-09-24

- Moving storage is 32 bytes per allocated slot: current position 12, packed
  velocity 4, packed displacement 4, colour index 2, stable slot 4, slot location
  4, and generation 2. Stationary storage omits velocity/displacement: 24 bytes.
  Palette, birth-cohort records, spawn scratch, batch rounding, and allocation
  page padding are additional. These are layout budgets, not measured footprint.
- Property streams remain dense four-particle SIMD batches with aligned host
  allocations. There is no padded per-particle struct. Packed vectors decode
  four particles at a time with SIMD shifts, masks/conversions, and multiplication.
- The compiler derives a signed fixed-point velocity scale from the authored
  range once. Ordinarily the step is a power of two large enough for ±511
  integer components; the extreme Float32 endpoint uses a finite fallback step.
  Encoding rounds to nearest, ties away from zero, and rejects out-of-range
  values rather than silently clamping. Quantization changes velocity/trajectory
  results and can round to an authored range endpoint. Existing full-precision
  checksums and performance results are historical, not new acceptance evidence.
- Current constant-velocity integration retains authoritative Float32 positions.
  The history word holds the same quantized components as velocity, with a shared
  displacement scale equal to velocity scale times tick delta. Renderers decode
  current minus displacement times (1 - alpha); no previous-position array is
  retained. Snapshot previous positions reconstruct the same displacement.
  Reset/seek clears history words. Future non-linear motion must explicitly
  compile its own displacement bounds/representation; it cannot assume this
  constant-velocity history shortcut.
- Lifetime scheduling uses FIFO consecutive-slot ranges sharing a UInt32 expiry
  tick (12 bytes per range). Tick narrowing uses wrapping addition and equality
  at every fixed tick, supporting expiry across UInt32 wrap. Normal spawning
  preallocates about one range per live birth tick, plus one recycling range.
  Explicit removal scans/splits ranges and can grow the queue; adversarial
  fragmentation can approach per-particle records. Removal is no longer O(1)
  in the number of cohort ranges; automatic expiry remains O(1) per particle.
- Palette changes on layout-compatible reconfiguration replace the immutable
  palette after reset; host-buffer identity invalidates the renderer wrapper.
  Public particle snapshots continue to expose semantic colours and vectors.
- Build-only validation for this change; app runs, correctness-test execution,
  and host/iPad/WebAssembly performance acceptance remain with the user.

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

## Shared Point and Billboard Rasterization

`ParticleRasterPass` owns point and billboard rendering on adapters advertising
64-bit atomic minimum (Metal: Apple GPU family 9 or newer). Both shapes use one
projection helper and the existing shared simulation buffers. Dense opaque
coverage resolves a 64-bit key per pixel (Float32 depth, then particle index),
then a fullscreen triangle writes the winning palette colour and scene depth.
Equal depths retain the earliest particle. Billboard coverage respects rotation,
world/screen sizing and all three facing modes.

Only wholly opaque palettes use compute coverage. The density gate is at least
65,536 particles and at least one particle per eight viewport pixels. Immutable
palette opacity is cached by buffer identity. Sparse and translucent batches use
the same pass's ordered geometry shader, retaining hardware premultiplied alpha
blending, strict less-than depth testing and depth writes, including zero alpha.
This preserves current compositing semantics; it is not order-independent
transparency. Unsupported devices, pipeline creation failure and the existing
LOD path retain the previous hardware rendering implementation.

The first coverage pass is bounded to 256 bounding-box pixels per particle.
Larger opaque billboards trigger GPU-only refinement: cooperatively rasterize
one particle in sixteen as depth seeds, summarize the farthest seeded depth in
each 8×8 pixel tile, conservatively reject fully occluded footprints, compact the
remaining original indices, then cooperatively rasterize their coverage. One
32-lane group processes each seeded or surviving footprint. Equal-depth ties
still use original particle indices; compaction order has no visual effect.
Empty seed pixels never occlude. Ordinary coverage and refinement share the same
projection, pixel coverage and winner storage. GPU indirect dispatch avoids
extra particle processing when ordinary coverage succeeds.

Footprints above 4096 bounding-box pixels still select the whole-batch ordered
geometry fallback and suppress compute resolve. This preserves extreme-size and
near-plane coverage, but those cases can still encounter hardware memory/time
cliffs. Transparent compositing remains unchanged.

Scratch is one GPU-only 8-byte winner per viewport pixel and a 32-byte argument
buffer. Opaque billboard refinement additionally reserves one 4-byte original
index per particle, one 4-byte depth per 8×8 pixel tile, and 12-byte dispatch
arguments. Storage is reused; refinement storage is released for points, and all
compute storage is released when compute is inactive. Fixed-function subpixel
rounding can differ from compute coverage; GPU image checks bound that difference
and require exact translucent, sparse, ordering and transition test images.

Visibility telemetry is sampled at most every 200 ms. Compute coverage counts
visible particles during its existing first pass; other paths use a 128-thread
SIMD reduction only on sampled frames. Counts refer to visibility before opaque
occlusion, not the compacted raster workload. Generation-tagged readback prevents
an older frame slot from replacing a newer count. GPU timestamps remain per frame.

Provisional measurements and validation are recorded in
`Benchmarks/Renderer/Metal/RESULTS-2026-09-25-billboards.md`. Opaque billboards
improve substantially; no reliable translucent speedup was measured.

The coverage kernel declares its existing 128-thread dispatch limit to the Metal
compiler. Local paired eight-million-particle measurements showed a modest
median improvement; no new buffers or simulation/draw changes were introduced.
See `Benchmarks/Renderer/Metal/RESULTS-2026-09-25-compute.md`. Benchmark invocations
clean native outputs to keep cross-module optimized Swift dispatch code and
Metal resources synchronized.
