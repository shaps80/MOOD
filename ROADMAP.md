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
- The GPU path supports fixed-capacity frame recording, render passes with read-only colour-format metadata, buffers, textures, samplers, pipelines, small vertex uniforms, large frame-owned vertex/instance data, indexed and non-indexed instanced draws, alpha blending, and explicit pooled-resource destruction on Metal and WebGPU. Metal retains three in-flight upload slots; WebGPU lowers the same command through its immediate buffer.
- Pixl owns the game lifecycle, fixed and variable updates, pause/time scaling, CPU frame metrics, PNG/WAV loading, stable texture and sound assets, and event-driven same-size hot reload on macOS. Its existing periodic summary now reports average queue lowering, culling, layer binning, ordering, batching, and instance-compaction CPU time separately from total render-command recording; no GPU workload is included. Browser assets remain packaged and static.
- Raw keyboard and gamepad state is portable across macOS and browsers. Pixl adds game-defined semantic input profiles, remapping, generated bindings, and axis movement helpers.
- Resident audio, reusable playback controllers, flat buses, rate/pan/volume/loop controls, and game-owned mixing work through AVFAudio and Web Audio. Streaming and compressed formats are not yet supported.
- Pixl2D owns the working value-semantic sprite authoring model: `Sprite`, nested `Sprite.Material`, `TextureRegion`, regular `SpriteSheet`, `SpriteAnimation.Timeline`, unsigned `RenderLayer` and layer-local `order`, alongside transforms and its orthographic camera. Sprite construction exposes every defaultable property while requiring only a region. Material sampling supports uniform presets and independent minification/magnification and horizontal/vertical addressing; initial composition intent is straight-alpha `.normal` or `.replace`.
- Pixl2D is independent of PixlPlatform and PixlFoundation. Its `Triangle` and `Quad` are plain geometry values, and its orthographic camera projects from viewport size or aspect ratio. Pixl bridges platform render targets to that pure API.
- `PixlFoundation` is an explicitly importable target beneath Pixl for lower-level engine infrastructure. Pixl depends on it directly; the horizontal graphics, 2D, and 3D domain targets do not.
- Pixl deliberately re-exports PixlGraphics as stable common graphics vocabulary. It does not re-export PixlPlatform, PixlFoundation, Pixl2D, or Pixl3D; required PixlPlatform identities remain selectively exposed through zero-cost type aliases, while direct lower-level or dimensional use requires explicit module imports.
- Pixl deliberately depends on PixlGraphics, Pixl2D, and Pixl3D as their orchestrator, so Game needs only the Pixl product while source explicitly imports the domain modules it uses. Horizontal domain targets do not acquire Foundation or Platform dependencies.
- PixlGraphics owns an independent `SIMD4<Float>` colour alias and named palette; PixlPlatform owns its own identical primitive alias. Pixl bridges graphics colour into platform frame recording without coupling PixlGraphics to PixlPlatform.
- PixlGraphics owns the value-semantic, platform-independent `TextureAsset` returned by Pixl's asset loader. PixlFoundation owns the public logical-identity-to-platform-resource mapping and lifetime plus context-owned sampler and pipeline caches. Existing same-size texture hot reload writes the stable resolved resource in place.
- `GameContext` owns the default fixed-capacity `RenderQueue`, configured by `Game.renderQueueSettings`. Pixl lowers each submitted Sprite and model-to-world transform into an immediate primitive snapshot, then automatically executes and resets the queue through `context.render(through:to:frame:clear:)` or its existing-pass overload.
- PixlFoundation now contains the prototype-derived CPU execution path: 48-byte ordinal-aligned instances, scalar union culling, sparse generation-stamped layer bins, varying-byte per-layer radix ordering by `(order, ordinal)`, per-view ordinal streams, consecutive material batch spans, and view-local upload compaction. Execution storage is manually allocated once from queue settings; hot stages do not use `Array`, `Dictionary`, general-purpose `Hasher`, or capacity growth.
- The retained `Pixl/Prototypes/RenderPipelinePrototype` reference has validated the intended single-threaded CPU execution design before Pixl integration: compact ordinal-aligned bounds, ordering, draw-key, and instance streams; contiguous multi-view scalar culling; compressed active-layer bins; per-layer packed-key radix ordering; per-view ordinal streams; and consecutive draw-key batch spans. Per-sprite spatial grids and cross-entity manual SIMD were rejected because they made this workload slower and more complex. `PERF.md` records its isolated prototype timings explicitly as directional evidence, not Pixl engine or GPU baselines.
- The provisional per-sprite `SpriteRenderer` and internal GPU `Quad` have been removed. The Game proof submits world transforms without camera/output coupling and records one indexed instanced draw per consecutive compatible batch. Native and WebAssembly builds pass; visual output and hot reload through this replacement await user verification.
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

### Implementation and Review Cadence

- Treat each numbered checkbox below as the smallest independently understandable unit. Normally implement only the next incomplete unit, build it, report the changed files and relevant behavior, then stop for the user's review and runtime testing. Adjacent units that mechanically port already-accepted prototype code may be combined when they introduce no new decision and the resulting diff remains comfortably reviewable; announce the exact combined scope before editing. Never bundle across an API, ownership, backend, data-layout, or measurement gate. Do not begin the following review slice until the user confirms the current one.
- For ordinary Pixl, PixlFoundation, PixlGraphics, Pixl2D, or Pixl3D work, validate compilation with the affected Xcode project or scheme only. Do not launch the Game or prototype, exercise hot reload, run interactive checks, or run automated tests unless the user explicitly requests them; the user owns testing during this workstream.
- If a slice changes PixlPlatform's portable contract or a concrete platform adapter, also validate the WebAssembly path. Otherwise do not build or test WebAssembly.
- Do not regenerate Xcode projects. Edit tracked project configuration directly only when the slice genuinely requires it and preserve user-owned build settings.
- Do not record measurements in `PERF.md` until the user accepts the exact result and asks for it to be retained.

### Stage 3 — Public Queue Lifecycle and Submission Seam

- [x] **3.1 — Name the execution API.** Keep `Game.render(on:output:frame:time:context:)`; add common `context.render(through:to:frame:clear:)` and advanced `context.render(through:to:on:)` consumption.
- [x] **3.2 — Complete 2D ordering intent.** Add unsigned sprite-local `order` and authoritative `(layer, local order, submission ordinal)` semantics.
- [x] **3.3 — Establish the Foundation execution seam.** Add camera-free projection and visible-bounds view data, retained multi-view-capable storage, and explicit execute/reset lifecycle. Viewport/scissor stays with the later public multi-view feature because the initial view covers its complete target.
- [x] **3.4 — Introduce the public submission queue.** Runtime-own the default fixed-capacity queue on `GameContext`; submit model-to-world values without camera, output, or pass.
- [x] **3.5 — Define Pixl consumption policy.** Pixl resets after success or failure; direct Foundation use exposes explicit execute/reset; unseen resources remain lazy and cached.
- [x] **3.6 — Verify the seam before CPU execution work.** The complete replacement now builds through the seam without a second GPU path.

### Stage 4 — Foundation CPU Execution Streams

- [x] **4.1 — Port lowering storage.** Fixed-capacity ordinal-aligned bounds, ordering, material-slot, and 48-byte instance streams.
- [x] **4.2 — Port union culling.** One contiguous scalar bounds traversal with per-view masks and union-visible ordinals.
- [x] **4.3 — Port sparse layer compression.** Persistent dense slots, generation stamps, active-slot sorting, prefix offsets, and contiguous scatter.
- [x] **4.4 — Port local ordering.** Stable varying-byte radix ordering within each active layer.
- [x] **4.5 — Port view filtering and batching.** One ordered-union traversal emits each view's ordinals and consecutive batch spans.
- [x] **4.6 — Review the complete CPU pipeline.** Production hot stages retain the prototype's data layout and manually managed allocation shape.

### Stage 5 — Material Keys and Shared Resource Resolution

- [x] **5.1 — Pack built-in draw keys.** Resolve complete sprite material intent through a fixed open-addressed registry and compact slots, with same-ordinal unchanged-value reuse.
- [x] **5.2 — Add shared sampler resolution.** Foundation lazily creates and reuses equivalent complete sampler descriptors outside hot execution.
- [x] **5.3 — Add shared pipeline resolution.** Foundation lazily caches variants by actual pass colour format and blend mode.
- [x] **5.4 — Finalize shared-resource lifecycle.** Context-owned Foundation resources outlive queue execution and preserve direct Platform resource ownership semantics.

### Stage 6 — Portable Indexed Instanced Drawing

- [x] **6.1 — Add portable instanced recording.** Frame-owned large vertex data complements the existing per-instance layout, instance count, and base instance commands.
- [x] **6.2 — Lower instancing through Metal and WebGPU.** Metal binds retained in-flight upload buffers; WebGPU binds the corresponding immediate-buffer range.
- [x] **6.3 — Decide GPU instance consumption.** Compact view-local upload records from the shared ordinal-aligned stream; keep this behind Foundation execution.
- [x] **6.4 — Review the portable capability.** Enforce the 48-byte Swift/shader instance ABI and compile both adapters.

### Stage 7 — Integrated Batched Sprite Rendering

- [x] **7.1 — Add frame-safe upload records.** Add retained CPU compaction, frame-owned copied bytes, and three Metal in-flight upload slots; validate both backend builds.
- [x] **7.2 — Encode consecutive batches.** Bind pipeline, texture, and sampler once per span and issue one indexed instanced draw.
- [x] **7.3 — Integrate the high-level single-view path.** Resolve one camera at execution and reset automatically through both convenience overloads.
- [ ] **7.4 — Migrate the Game.** Code migration is complete and builds; user verification of visuals and hot reload is pending.
- [x] **7.5 — Remove proof rendering.** Delete the provisional per-sprite renderer, temporary GPU quad, and their obsolete tests.
- [ ] **7.6 — Review integrated behavior.** Cover sparse layers, local order, equal-order stability, alternating materials, material mutation, capacity boundaries, one camera, and multiple render calls. Add dirty tracking only if a concrete persistent mutable GPU record was introduced. Expose and test split-screen only in its later dedicated feature slice.

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

- [ ] Generalize the current frame-safe vertex upload lifetime only when another stage needs buffer writes or copy commands; define a separate completion-safe readback lifetime before exposing readback.

### Audio

- [ ] Add an explicit streaming sound source; music should use streaming by default.
- [ ] Add compressed formats only when a playable Game need justifies decoder and packaging costs.
- [ ] Move Web Audio graph control behind an AudioWorklet or worker boundary only if profiling shows current control-thread work affecting frames.

### Platform Reach

- [ ] Carry the proven portable contract beyond macOS and WebAssembly to Windows, iOS, tvOS, and visionOS without leaking platform concepts upward.
