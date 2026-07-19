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
- The Game proof exercises character movement, keyboard/gamepad bindings, layered animated sprites, pause/time scaling, music, asset loading, and frame metrics without backend-specific game code.
- `PixlConcurrency` is an optional standalone package with persistent lane groups, static and dynamic partitioning, reusable barriers, native worker threads, and a single-lane WASI path. Pixl does not depend on or re-export it.

## Next Priority — Instanced Sprite Batching

- [ ] Batch compatible consecutive sprite submissions without changing Game's `submit` API.
  - Preserve authoritative layer and submission order; never reorder sprites to create larger batches.
  - Begin with compatibility across render pass, pipeline, texture, sampler, and blend state. Incompatible state flushes the current batch rather than requiring another renderer.
  - Move per-sprite transforms and texture coordinates into retained high-water instance storage, then emit one instanced draw per compatible run.
  - Keep platform work to portable instanced vertex-layout and draw capability plus minimal Metal/WebGPU lowering.
  - Verify no steady-state CPU allocation. Measure the representative bullets/enemies workload and separate 10,000-visible-sprite stress case on native and browser before recording accepted baselines in `PERF.md`.
  - Keep entity storage, simulation, collision, culling, atlases, and tile sets outside this slice.

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
