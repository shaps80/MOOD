# Pixl Roadmap

This file is a compact view of where Pixl is and what should happen next. It is not a history of completed work.

## Maintenance

- Keep **Current State** short enough to read at the start of every session.
- When work completes, fold its lasting capability into **Current State**, then remove its checkbox. Do not retain completed-task history here.
- Keep checklists limited to concrete, unfinished outcomes. Put stable architecture and vocabulary in `CONTEXT.md`, accepted measurements in `PERF.md`, and implementation detail in code and tests.
- Rewrite or remove stale items as the product direction changes; do not preserve abandoned plans for continuity.
- Update this file whenever a completed vertical slice materially changes the current state or next priority.

## Current State

- Pixl is a cross-platform Swift game engine with one game-facing source path running on macOS through Metal and in browsers through WebGPU.
- `PixlPlatform` provides low-level portable GPU, runtime, raw-input, audio, and asset-source contracts. Concrete adapters own native framework code and backend-specific lowering.
- The GPU path supports fixed-capacity frame recording, render passes with read-only colour-format metadata, buffers, textures, samplers, pipelines, vertex bytes, indexed and non-indexed draws, alpha blending, and explicit pooled-resource destruction on Metal and WebGPU.
- Pixl owns the game lifecycle, fixed and variable updates, pause/time scaling, CPU frame metrics, PNG/WAV loading, stable texture and sound assets, and event-driven same-size hot reload on macOS. Browser assets remain packaged and static.
- Raw keyboard and gamepad state is portable across macOS and browsers. Pixl adds game-defined semantic input profiles, remapping, generated bindings, and axis movement helpers.
- Resident audio, reusable playback controllers, flat buses, rate/pan/volume/loop controls, and game-owned mixing work through AVFAudio and Web Audio. Streaming and compressed formats are not yet supported.
- Pixl2D owns the working value-semantic sprite authoring model: `Sprite`, nested `Sprite.Material`, `TextureRegion`, regular `SpriteSheet`, `SpriteAnimation.Timeline`, and `RenderLayer`, alongside transforms and its orthographic camera. Sprite construction exposes every defaultable property while requiring only a region. Material sampling supports uniform presets and independent minification/magnification and horizontal/vertical addressing; initial composition intent is straight-alpha `.normal` or `.replace`. Pixl retains only the asset-loading convenience and provisional `SpriteRenderer`, which currently records one draw per sprite and is not an architectural constraint.
- Pixl2D is independent of PixlPlatform and PixlFoundation. Its `Triangle` and `Quad` are plain geometry values, and its orthographic camera projects from viewport size or aspect ratio. Pixl bridges platform render targets to that pure API.
- `PixlFoundation` is an explicitly importable target beneath Pixl for lower-level engine infrastructure. Pixl depends on it directly; the horizontal graphics, 2D, and 3D domain targets do not.
- Pixl deliberately re-exports PixlGraphics as stable common graphics vocabulary. It does not re-export PixlPlatform, PixlFoundation, Pixl2D, or Pixl3D; required PixlPlatform identities remain selectively exposed through zero-cost type aliases, while direct lower-level or dimensional use requires explicit module imports.
- Pixl deliberately depends on PixlGraphics, Pixl2D, and Pixl3D as their orchestrator, so Game needs only the Pixl product while source explicitly imports the domain modules it uses. Horizontal domain targets do not acquire Foundation or Platform dependencies.
- PixlGraphics owns an independent `SIMD4<Float>` colour alias and named palette; PixlPlatform owns its own identical primitive alias. Pixl bridges graphics colour into platform frame recording without coupling PixlGraphics to PixlPlatform.
- PixlGraphics owns the value-semantic, platform-independent `TextureAsset` returned by Pixl's asset loader. PixlFoundation owns the logical-identity-to-platform-resource mapping and lifetime; the provisional context-owned renderer resolves through that store. Existing Game rendering and same-size texture hot reload have been verified after this separation.
- PixlFoundation has backend-free fixed-capacity sprite submission storage. Pixl lowers each Sprite and transform into an independent primitive CPU snapshot containing order, transformed geometry state, texture identity and coordinates, and complete material sampling/composition intent. Consumption sorts by `(layer, ordinal)`, resets without releasing storage, and has tested overflow and allocation reuse.
- The retained `Pixl/Prototypes/RenderPipelinePrototype` reference has validated the intended single-threaded CPU execution design before Pixl integration: compact ordinal-aligned bounds, ordering, draw-key, and instance streams; contiguous multi-view scalar culling; compressed active-layer bins; per-layer packed-key radix ordering; per-view ordinal streams; and consecutive draw-key batch spans. Per-sprite spatial grids and cross-entity manual SIMD were rejected because they made this workload slower and more complex. `PERF.md` records its isolated prototype timings explicitly as directional evidence, not Pixl engine or GPU baselines.
- The working sprite renderer temporarily retains an internal Pixl GPU `Quad`; it preserves existing output while its buffers, packed parameters, layout, and draw recording await deliberate replacement by Foundation-level execution machinery.
- The Game proof exercises character movement, keyboard/gamepad bindings, layered animated sprites, pause/time scaling, music, asset loading, and frame metrics without backend-specific game code.
- `PixlConcurrency` is an optional standalone package with persistent lane groups, static and dynamic partitioning, reusable barriers, native worker threads, and a single-lane WASI path. Pixl does not depend on or re-export it.

## Next Priority — 2D Domain Ownership Through Instanced Batching

Implement the agreed design in review-sized stages, fixing ownership before enriching the provisional renderer. Each stage must leave its abstraction tested and coherent; it need not manufacture a new Game feature merely to qualify as a vertical slice. Existing texture assets, `SpriteRenderer`, sampler ownership, blend modes, and GPU quad code may be replaced or deleted wherever the architecture requires it.

### Stage Continuity

- `CONTEXT.md` is the durable design source across sessions. Record any changed vocabulary, ownership, public API, data-frequency boundary, cache semantics, ordering rule, or backend responsibility there when the decision changes.
- Keep only the active and unfinished implementation stages below. When a stage completes, fold its lasting capability into **Current State**, preserve its architectural decisions in `CONTEXT.md`, record accepted measurements in `PERF.md`, then remove its completed checklist.
- Before splitting a stage across sessions, leave its completed facts, remaining gate, relevant tests, and next smallest review unit in that stage rather than relying on conversation history.
- Do not silently broaden a later stage to absorb an unresolved earlier decision. Record the gate explicitly and resolve it before dependent work proceeds.
- If implementation requires a direction change or any API, ownership, performance, data-layout, or backend decision not explicitly settled in `CONTEXT.md`, stop before implementing it, cite the concrete reason, and ask for direction through discussion.

### Stage 3 — Public Queue Lifecycle and Submission Seam

- [ ] Before implementing public `RenderQueue.encode(on:)`, agree whether shared Foundation render resources initialize lazily and whether cold resource creation makes encoding throwing; every other public ownership, capacity, lifetime, and pass-compatibility decision is settled.
- [ ] Agree and implement the smallest execution/reset API that lets one submitted queue execute for one or several camera views, including split screen, without attaching cameras to sprites or introducing automatic scene rendering.
- [ ] Replace or delete provisional `SpriteRenderer` responsibilities so Pixl receives Pixl2D values while PixlFoundation owns fixed-capacity execution storage and PixlPlatform receives only explicit resolved commands.
- [ ] Add Pixl2D's unsigned sprite-local `order`; preserve immediate snapshot semantics so mutate-and-resubmit captures two independent values in one frame.
- [ ] Keep `Sprite` as the obvious authoring entry point with minimum-plus-defaultable initializers; do not expose internal keys, registration, resolution, or engine storage through the ordinary game API.
- [ ] Test submit/mutate/submit behavior, queue reuse/reset, capacity failure, one view, overlapping split-screen views, and absence of steady-state allocation.

### Stage 4 — Foundation CPU Execution Streams

- [ ] Replace wide-record execution with fixed-capacity ordinal-aligned bounds, ordering, draw-key, and 48-byte instance candidate streams; keep public snapshots, CPU execution records, and GPU ABI distinct.
- [ ] Traverse bounds contiguously once, build per-submission view masks, and emit the union-visible ordinal set without a per-sprite spatial index.
- [ ] Resolve arbitrary unsigned layers to dense internal slots, count with generation stamps, sort only active layer slots, prefix offsets, and scatter packed ordering keys into contiguous per-layer ranges.
- [ ] Radix-order each active layer by the varying bytes of `(local order, submission ordinal)` and preserve equal-order stability without whole-record comparison sorting.
- [ ] Traverse the ordered union once to emit per-view ordinal streams and consecutive draw-key batch spans; do not reorder for larger batches or copy full CPU instance records per view.
- [ ] Use manually managed retained-capacity storage throughout measured execution; no `Array`, `Dictionary`, hashing through general-purpose `Hasher`, or steady-state allocation in these paths.
- [ ] Test sparse and changing layers, local-order boundaries, equal-order stability, visibility overlap, alternating draw keys, batch-span boundaries, capacity limits, and deterministic queue reuse.

### Stage 5 — Material Keys and Shared Resource Resolution

- [ ] Resolve built-in sprite intent into bounded compact material/draw keys; use packed fields or direct indexing where appropriate rather than assuming general-purpose hot-path hashing.
- [ ] Resolve a public material change on its next submission without changing transform, flip, region, animation, or layer mutation semantics.
- [ ] Add PixlFoundation descriptor-to-resource caches for samplers and built-in pipeline variants, shared at the device/runtime level rather than owned by one submission domain.
- [ ] Reuse one native resource for each equivalent complete descriptor; distinct descriptor properties resolve independently and only unseen descriptions take a cold creation path.
- [ ] Define cached-resource ownership and destruction so one consumer cannot invalidate shared resources while direct `Device.make*` resources retain explicit caller ownership.
- [ ] Treat configured capacities as limits on simultaneously live unique native resources and test accounting after deduplication.

### Stage 6 — Portable Indexed Instanced Drawing

- [ ] Add the smallest portable vertex-step/instance-layout and instance-count API required by sprite rendering.
- [ ] Decide the GPU consumption gate by measuring direct fetch from one ordinal-aligned instance stream through each view's ordinal index stream versus compacting view-local upload records; keep this backend/execution decision out of the public Sprite API.
- [ ] Lower the capability through Metal and WebGPU without exposing backend binding models.
- [ ] Verify instance indexing, vertex layout, draw recording, capacity failure, and backend lowering independently of sprite batching.

### Stage 7 — Integrated Batched Sprite Rendering

- [ ] Verify Swift/shader ABI size, stride, alignment, and padding on Metal and WebGPU.
- [ ] Add frame-safe upload lifetime without steady-state allocation; introduce frame or material records only when concrete shader data requires them.
- [ ] Bind each batch's resolved pipeline, texture, and sampler once, then emit one instanced draw for its consecutive span.
- [ ] Preserve authoritative ordering and per-view visibility while sharing union execution work across views.
- [ ] Remove the provisional per-sprite draw and internal GPU `Quad` path once the replacement renders identical Game output.
- [ ] Test sparse layers, local order, equal-order stability, alternating materials, material mutation, capacity boundaries, one camera, overlapping split-screen cameras, and multiple render calls.
- [ ] Add dirty tracking only if concrete persistent mutable GPU records are introduced; ordinary immediate snapshots do not require it.

### Stage 8 — Game and Performance Verification

- [ ] Exercise mixed nearest/linear filtering and multiple blend modes through the Game without backend-specific game code.
- [ ] Exercise independent offscreen-world and native-resolution UI submission destinations if their target formats expose distinct pipeline variants.
- [ ] Verify no steady-state CPU allocation.
- [ ] Profile material-key derivation, resolved-resource lookup, ordering, and instance writes separately so avoidable submission cost remains visible.
- [ ] Measure the representative bullets/enemies workload and a separate 10,000-visible-sprite stress case on native and browser, then record only accepted baselines in `PERF.md`.

Keep entity storage, scene ownership, simulation, collision, per-sprite spatial acceleration, tile sets, and automatic rendering outside this work. Render-time scalar bounds culling over submitted values is part of Foundation execution; persistent world visibility and coarse tilemap/chunk acceleration are game or future domain-library concerns. Texture-region and regular-sheet ownership moves now; irregular named atlases remain later work.

Before implementing the fuller material capability phase—tint/modulation placement, opacity, normal/emission/mask textures, lighting parameters, alpha cutoff, and sharing/mutation semantics—stop for the dedicated planning session required by `CONTEXT.md`.

Before relocating existing cross-boundary audio/runtime types, perform a dedicated ownership review. `Bus` and `Playback` currently contain engine-level lifecycle and routing policy that may not belong in PixlPlatform; `Platform`, `Frame`, `RenderTarget`, `GamePhase`, and `GameSettings` remain in place for now. Do not rename or move them incidentally during sprite work.

## Near-Term Work

### First Game and 2D Rendering

- [ ] Route future backgrounds, tiles, players, enemies, and UI through the agreed immediate submission path as the Game needs them.
- [ ] Add named irregular `TextureAtlas` regions when the Game needs them.
- [ ] Add a visual `TileSet` mapping from game-owned tile identifiers to atlas regions without introducing engine-owned world or tilemap storage.

### GPU Foundations

- [ ] Add reusable internal upload-ring and readback lifetimes before exposing stage-specific larger dynamic bytes, buffer writes, copy commands, or readback.

### Audio

- [ ] Add an explicit streaming sound source; music should use streaming by default.
- [ ] Add compressed formats only when a playable Game need justifies decoder and packaging costs.
- [ ] Move Web Audio graph control behind an AudioWorklet or worker boundary only if profiling shows current control-thread work affecting frames.

### Platform Reach

- [ ] Carry the proven portable contract beyond macOS and WebAssembly to Windows, iOS, tvOS, and visionOS without leaking platform concepts upward.
