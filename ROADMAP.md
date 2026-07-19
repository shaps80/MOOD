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
- The GPU path supports fixed-capacity frame recording, render passes, buffers, textures, samplers, pipelines, vertex bytes, indexed and non-indexed draws, alpha blending, and explicit pooled-resource destruction on Metal and WebGPU.
- Pixl owns the game lifecycle, fixed and variable updates, pause/time scaling, CPU frame metrics, PNG/WAV loading, stable texture and sound assets, and event-driven same-size hot reload on macOS. Browser assets remain packaged and static.
- Raw keyboard and gamepad state is portable across macOS and browsers. Pixl adds game-defined semantic input profiles, remapping, generated bindings, and axis movement helpers.
- Resident audio, reusable playback controllers, flat buses, rate/pan/volume/loop controls, and game-owned mixing work through AVFAudio and Web Audio. Streaming and compressed formats are not yet supported.
- The 2D stack includes transforms, an orthographic camera, texture regions, regular sprite sheets, animation timelines, render layers, and a shared retained `SpriteRenderer`. It currently records one draw per sprite.
- Pixl2D is independent of PixlPlatform and PixlFoundation. Its `Triangle` and `Quad` are plain geometry values, and its orthographic camera projects from viewport size or aspect ratio. Pixl bridges platform render targets to that pure API.
- `PixlFoundation` is an explicitly importable target beneath Pixl for lower-level engine infrastructure. Pixl depends on it directly; the horizontal graphics, 2D, and 3D domain targets do not.
- Pixl no longer broadly re-exports PixlPlatform or PixlGraphics. Its common API selectively exposes required shared identities through zero-cost type aliases, while direct lower-level use requires explicit module imports.
- Pixl deliberately depends on PixlGraphics, Pixl2D, and Pixl3D as their orchestrator, so Game needs only the Pixl product while source explicitly imports the domain modules it uses. Horizontal domain targets do not acquire Foundation or Platform dependencies.
- PixlGraphics owns an independent `SIMD4<Float>` colour alias and named palette; PixlPlatform owns its own identical primitive alias. Pixl bridges graphics colour into platform frame recording without coupling PixlGraphics to PixlPlatform.
- The working sprite renderer temporarily retains an internal Pixl GPU `Quad`; it preserves existing output while its buffers, packed parameters, layout, and draw recording await deliberate replacement by Foundation-level execution machinery.
- The Game proof exercises character movement, keyboard/gamepad bindings, layered animated sprites, pause/time scaling, music, asset loading, and frame metrics without backend-specific game code.
- `PixlConcurrency` is an optional standalone package with persistent lane groups, static and dynamic partitioning, reusable barriers, native worker threads, and a single-lane WASI path. Pixl does not depend on or re-export it.

## Next Priority — Resolved Sprite Materials and Instanced Batching

Implement the agreed design in review-sized stages. Each stage must leave its abstraction tested and coherent; it need not manufacture a new Game feature merely to qualify as a vertical slice. Preserve the agreed explicit sprite-submission model, but treat the brand-new `SpriteRenderer`, sampler ownership, blend modes, and their exact APIs as provisional code that should change wherever the architecture requires it.

### Stage Continuity

- `CONTEXT.md` is the durable design source across sessions. Record any changed vocabulary, ownership, public API, data-frequency boundary, cache semantics, ordering rule, or backend responsibility there when the decision changes.
- Keep only the active and unfinished implementation stages below. When a stage completes, fold its lasting capability into **Current State**, preserve its architectural decisions in `CONTEXT.md`, record accepted measurements in `PERF.md`, then remove its completed checklist.
- Before splitting a stage across sessions, leave its completed facts, remaining gate, relevant tests, and next smallest review unit in that stage rather than relying on conversation history.
- Do not silently broaden a later stage to absorb an unresolved earlier decision. Record the gate explicitly and resolve it before dependent work proceeds.
- If implementation requires a direction change or any API, ownership, performance, data-layout, or backend decision not explicitly settled in `CONTEXT.md`, stop before implementing it, cite the concrete reason, and ask for direction through discussion.

### Stage 1 — Sprite Material Intent

- [ ] Evolve `Sprite` to include a lightweight, value-semantic nested `Sprite.Material` description covering filtering, addressing, and the supported `BlendMode` set.
- [ ] Keep `Sprite` as the obvious entry point with useful defaults; do not introduce a parallel factory or competing top-level material type.
- [ ] Keep sprite construction and mutation ordinary Swift value APIs; material keys and resource ownership remain internal.
- [ ] Resolve material changes on the next submission without changing transform, flip, tint, region, or layer mutation semantics.
- [ ] Test defaults, value equivalence, key differences, and mutation independently of native resource creation; keep steady-state key derivation bounded and allocation-free.

### Stage 2 — Shared Resource Resolution

- [ ] Add engine-owned descriptor-to-resource resolution for samplers and built-in sprite pipeline variants, shared at the device/runtime level rather than owned by individual sprite renderers.
- [ ] Reuse one native resource for equivalent complete descriptors; distinct descriptor properties resolve independently.
- [ ] Define cached-resource ownership and destruction so one renderer cannot invalidate resources used by another while direct `Device.make*` resources retain explicit caller ownership.
- [ ] Keep `RenderSettings` capacities as limits on simultaneously live unique native resources and test capacity accounting after deduplication.
- [ ] Exercise material and cache resolution through the current one-draw-per-sprite renderer before adding instanced recording.

### Stage 3 — Portable Instanced Drawing

- [ ] Add the smallest portable vertex-step/instance-layout and instance-count API required by sprite rendering.
- [ ] Lower the capability through Metal and WebGPU without exposing backend binding models.
- [ ] Verify instance indexing, vertex layout, draw recording, capacity failure, and backend lowering independently of sprite batching.

### Stage 4 — Retained Instance Data

- [ ] Define the explicit fixed-stride instance record required by the built-in sprite shader, keeping public, CPU-retained, and GPU-upload representations separate.
- [ ] Move per-sprite transform, texture coordinates, tint, and flip results into retained high-water interleaved instance storage.
- [ ] Verify Swift/shader ABI size, stride, alignment, and padding on Metal and WebGPU.
- [ ] Add frame-safe upload lifetime without steady-state allocation; introduce frame or material records and dirty tracking only when concrete shader data requires them.
- [ ] First prove the instanced path with one instance per draw so data-layout failures remain separate from batch-formation failures.

### Stage 5 — Consecutive Batch Formation

- [ ] Batch consecutive compatible sprite submissions across pipeline variant, texture, sampler, blend state, target state, and required material bindings.
- [ ] Preserve authoritative layer and submission order; never reorder sprites to create larger batches.
- [ ] Flush on compatibility changes and emit one instanced draw per compatible run.
- [ ] Test ordered and unordered layers, equal-layer stability, alternating materials, material mutation, capacity boundaries, and multiple render calls.

### Stage 6 — Game and Performance Verification

- [ ] Exercise mixed nearest/linear filtering and multiple blend modes through the Game without backend-specific game code.
- [ ] Exercise independent offscreen-world and native-resolution UI sprite-renderer destinations if their target formats expose distinct pipeline variants.
- [ ] Verify no steady-state CPU allocation.
- [ ] Profile material-key derivation, resolved-resource lookup, ordering, and instance writes separately so avoidable submission cost remains visible.
- [ ] Measure the representative bullets/enemies workload and a separate 10,000-visible-sprite stress case on native and browser, then record only accepted baselines in `PERF.md`.

Keep entity storage, scene ownership, simulation, collision, culling, atlases, tile sets, and automatic rendering outside this work.

Before implementing the fuller material capability phase—tint/modulation placement, opacity, normal/emission/mask textures, lighting parameters, alpha cutoff, and sharing/mutation semantics—stop for the dedicated planning session required by `CONTEXT.md`.

Before relocating existing cross-boundary audio/runtime types, perform a dedicated ownership review. `Bus` and `Playback` currently contain engine-level lifecycle and routing policy that may not belong in PixlPlatform; `Platform`, `Frame`, `RenderTarget`, `GamePhase`, and `GameSettings` remain in place for now. Do not rename or move them incidentally during sprite work.

## Near-Term Work

### First Game and 2D Rendering

- [ ] Route future backgrounds, tiles, players, enemies, and UI through the shared renderer as the Game needs them.
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
