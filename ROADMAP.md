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
- Pixl2D owns the working value-semantic sprite authoring model: `Sprite`, `TextureRegion`, regular `SpriteSheet`, `SpriteAnimation.Timeline`, and `RenderLayer`, alongside transforms and its orthographic camera. Pixl retains only the asset-loading convenience and provisional `SpriteRenderer`, which currently records one draw per sprite and is not an architectural constraint.
- Pixl2D is independent of PixlPlatform and PixlFoundation. Its `Triangle` and `Quad` are plain geometry values, and its orthographic camera projects from viewport size or aspect ratio. Pixl bridges platform render targets to that pure API.
- `PixlFoundation` is an explicitly importable target beneath Pixl for lower-level engine infrastructure. Pixl depends on it directly; the horizontal graphics, 2D, and 3D domain targets do not.
- Pixl deliberately re-exports PixlGraphics as stable common graphics vocabulary. It does not re-export PixlPlatform, PixlFoundation, Pixl2D, or Pixl3D; required PixlPlatform identities remain selectively exposed through zero-cost type aliases, while direct lower-level or dimensional use requires explicit module imports.
- Pixl deliberately depends on PixlGraphics, Pixl2D, and Pixl3D as their orchestrator, so Game needs only the Pixl product while source explicitly imports the domain modules it uses. Horizontal domain targets do not acquire Foundation or Platform dependencies.
- PixlGraphics owns an independent `SIMD4<Float>` colour alias and named palette; PixlPlatform owns its own identical primitive alias. Pixl bridges graphics colour into platform frame recording without coupling PixlGraphics to PixlPlatform.
- PixlGraphics owns the value-semantic, platform-independent `TextureAsset` returned by Pixl's asset loader. PixlFoundation owns the logical-identity-to-platform-resource mapping and lifetime; the provisional context-owned renderer resolves through that store. Existing Game rendering and same-size texture hot reload have been verified after this separation.
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

### Stage 2 — Pixl2D Sprite Authoring Model

- [ ] Give `Sprite` a lightweight nested value-semantic `Sprite.Material` covering texture, filtering, addressing, and `BlendMode` with useful defaults; agree the exact initial blend cases and the role of layer in Sprite construction before changing this public shape.
- [ ] Keep `Sprite` the obvious entry point; construction and mutation remain ordinary Swift value APIs with no registration, native resource, cache, or execution concepts.
- [ ] Add only the Pixl-owned convenience extensions needed to bridge context/Foundation-backed operations into domain values through package-scoped initializers; do not create dependency cycles or expose package-only Foundation types publicly.
- [ ] Update Pixl type aliases only where one PixlPlatform identity is required by its common API; preserve PixlGraphics as the sole re-export and do not re-export Pixl2D, Pixl3D, PixlFoundation, or PixlPlatform.

### Stage 3 — Immediate Submission and Lowering Seam

- [ ] Before implementing the public surface, agree the exact name, owner, lifetime, and render-pass relationship of the explicit submission entry point; do not preserve `SpriteRenderer` merely for compatibility.
- [ ] Replace or delete the provisional `SpriteRenderer` responsibilities so Pixl receives Pixl2D values while PixlFoundation owns retained execution storage, ordering data, compact records, and resolved resources.
- [ ] Snapshot every relevant sprite and transform value at submission time; later mutation must not alter prior submissions, and ordinary sprites must not require registration or retained engine identity.
- [ ] Lower domain values into primitive Foundation records without Foundation storing semantic `Sprite`, `Triangle`, or `Quad` values.
- [ ] Preserve authoritative layer/submission order and the current one-draw-per-sprite output before adding instancing or batch formation.
- [ ] Test submit/mutate/submit behavior, frame reset, capacity failure, layer stability, and absence of steady-state allocation.

### Stage 4 — Material Keys and Shared Resource Resolution

- [ ] Resolve built-in sprite intent into bounded compact material/draw keys; use packed fields or direct indexing where appropriate rather than assuming general-purpose hot-path hashing.
- [ ] Resolve a public material change on its next submission without changing transform, flip, region, animation, or layer mutation semantics.
- [ ] Add PixlFoundation descriptor-to-resource caches for samplers and built-in pipeline variants, shared at the device/runtime level rather than owned by one submission domain.
- [ ] Reuse one native resource for each equivalent complete descriptor; distinct descriptor properties resolve independently and only unseen descriptions take a cold creation path.
- [ ] Define cached-resource ownership and destruction so one consumer cannot invalidate shared resources while direct `Device.make*` resources retain explicit caller ownership.
- [ ] Treat configured capacities as limits on simultaneously live unique native resources and test accounting after deduplication.

### Stage 5 — Portable Instanced Drawing

- [ ] Add the smallest portable vertex-step/instance-layout and instance-count API required by sprite rendering.
- [ ] Lower the capability through Metal and WebGPU without exposing backend binding models.
- [ ] Verify instance indexing, vertex layout, draw recording, capacity failure, and backend lowering independently of sprite batching.

### Stage 6 — Retained Instance Data and Consecutive Batches

- [ ] Define the explicit fixed-stride instance record required by the built-in sprite shader, keeping public, CPU-retained, and GPU-upload representations separate.
- [ ] Move per-sprite transform, texture coordinates, tint, and flip results into retained high-water interleaved instance storage.
- [ ] Verify Swift/shader ABI size, stride, alignment, and padding on Metal and WebGPU.
- [ ] Add frame-safe upload lifetime without steady-state allocation; introduce frame or material records only when concrete shader data requires them.
- [ ] First prove the instanced path with one instance per draw so data-layout failures remain separate from batch-formation failures.
- [ ] Batch consecutive compatible sprite submissions across pipeline variant, texture, sampler, blend state, target state, and required material bindings.
- [ ] Preserve authoritative layer and submission order; never reorder sprites to create larger batches.
- [ ] Flush on compatibility changes and emit one instanced draw per compatible run.
- [ ] Test ordered and unordered layers, equal-layer stability, alternating materials, material mutation, capacity boundaries, and multiple render calls.
- [ ] Add dirty tracking only if concrete persistent mutable GPU records are introduced; ordinary immediate snapshots do not require it.

### Stage 7 — Game and Performance Verification

- [ ] Exercise mixed nearest/linear filtering and multiple blend modes through the Game without backend-specific game code.
- [ ] Exercise independent offscreen-world and native-resolution UI submission destinations if their target formats expose distinct pipeline variants.
- [ ] Verify no steady-state CPU allocation.
- [ ] Profile material-key derivation, resolved-resource lookup, ordering, and instance writes separately so avoidable submission cost remains visible.
- [ ] Measure the representative bullets/enemies workload and a separate 10,000-visible-sprite stress case on native and browser, then record only accepted baselines in `PERF.md`.

Keep entity storage, scene ownership, simulation, collision, culling, tile sets, and automatic rendering outside this work. Texture-region and regular-sheet ownership moves now; irregular named atlases remain later work.

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
