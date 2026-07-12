# Pixl Roadmap

This file tracks architectural work across sessions. It records direction and decision gates, not delivery promises. Concrete APIs should still emerge from playable Game needs.

## Current Foundation

- [x] Separate dimension-agnostic `PixlPlatform` GPU layer from higher-level graphics APIs.
- [x] Add `Pixl2D` and `Pixl3D` targets above shared `PixlGraphics` infrastructure.
- [x] Extract the platform-agnostic lane-based execution layer into the standalone `PixlConcurrency` sibling package.
- [x] Add native performance coverage and native/WASM Swift Testing correctness coverage for `PixlConcurrency`.
- [x] Prototype static lane programs, balanced ranges, leader-only work, and reusable barriers; retain the API direction but reject the initial condition-variable barrier.
- [x] Validate the first Metal path with compiled shaders, a GPU-only vertex buffer, a render pipeline, and a visible triangle.
- [x] Establish explicit buffer memory intent: GPU-only, CPU-visible, and GPU-to-CPU.
- [x] Build the same Game package for WASM and render its unchanged triangle through `PixlWasmPlatform` and WebGPU.
- [x] Keep `PixlConcurrency` available under the supported single-threaded WASI SDK through its one-lane execution path.
- [x] Refocus the portable recording interface on Metal-style encoder/resource-slot commands, using modern DirectX as the secondary alignment reference.
- [x] Remove public `Pass`/`DrawCommand` storage details; record compact package-only commands through `RenderPassEncoder`.
- [x] Move exact primitive topology to `drawPrimitives` and preserve line/triangle strip semantics.
- [x] Add explicit destruction for pooled buffer, texture, and render-pipeline handles.

## Next Architectural Decisions

### Runtime Loop and Timing

- [x] Define a platform-neutral Pixl loop driven by each platform's presentation callback.
- [x] Define variable-step and optional fixed-step update behavior.
- [x] Define elapsed time, accumulator limits, interpolation, and long-frame handling.
- [ ] Define deterministic safe points where queued editor/live-development changes may be applied without racing simulation or render preparation.
- [ ] Define development hooks as part of the loop lifecycle without making editor behavior part of release-game policy.
- [ ] Keep editor mutations queued until a safe point; never let editor code mutate live simulation state concurrently.
- [ ] Keep platform presentation callbacks separate from game simulation policy.
- [ ] Make the loop boundaries suitable for later parallel work without requiring a job system now.

### Parallel Execution

- [ ] Design a Ryan-style multi-core-by-default lane model rather than a conventional generic job system.
- [ ] Define persistent lane-group lifetime, lane index/count, barriers, range partitioning, and narrow execution.
- [x] Keep `PixlConcurrency` portable and independent of `PixlMetalPlatform` or another concrete platform.
- [ ] Decide the portable worker launch/parking backend only when the lane model requires it; add Swift Atomics only when an atomic primitive is implemented.
- [ ] Prefer explicit ownership, dependencies, and deterministic synchronization over task-per-entity or allocation-heavy scheduling.
- [ ] Decide which work can run concurrently: simulation systems, culling, batching, asset processing, and render preparation.
- [ ] Keep UI, drawable acquisition, and platform-required presentation work on the platform's required executor.
- [ ] Define an optional serial editor executor/lane, distinct from the OS UI thread and without reserving a CPU core.
- [ ] Give the editor separate CPU-memory and work budgets; run it event-driven or at a lower update rate when appropriate.
- [ ] Exchange immutable snapshots/events from game to editor and fixed-capacity mutation commands from editor to game.
- [ ] Keep editor overlays on the normal render submission path; do not create a competing GPU queue.
- [ ] Measure representative workloads before committing to scheduler complexity.

### Live Development

- [ ] Treat the editor as an optional in-game Pixl subsystem so its core UI and behavior can run across supported platforms.
- [ ] Keep the in-game editor's state isolated from live game state; inspect snapshots and issue commands rather than sharing mutable ownership.
- [ ] Keep the host process focused on capabilities the game cannot provide itself: file watching, builds, diagnostics, remote transport, and optional source writeback.
- [ ] Design a host/client development connection for file watching, change notification, diagnostics, and remote targets.
- [ ] Queue remote/editor mutations and apply them only at explicit loop safe points.
- [ ] Support genuine live reload for assets, generated shader artifacts, data, and configuration.
- [ ] Define the Swift source-change workflow separately: fast rebuild/relaunch with optional state restoration rather than promising portable native-code replacement.
- [ ] Explore stable, serializable editable-state metadata generated by macros or property wrappers.
- [ ] Explore an in-game editor for changing registered values while the game runs.
- [ ] Persist edited values as development overrides so they survive relaunches.
- [ ] Consider source-code writeback tooling only after the editable-state workflow proves useful.

## Graphics Follow-up

- [x] Surface allocation-free portable frame interval, FPS, CPU game-update, and CPU render-recording metrics through `RenderTime`; GPU timing remains a later backend capability.
- [x] Revalidate the static triangle through the refocused `PixlPlatform` and `PixlMetalPlatform` API before adapting the WebGPU backend.
- [x] Adapt `PixlWasmPlatform` to the accepted Metal-first portable command interface; keep WebGPU bind-group/pipeline-layout machinery private to the adapter.
- [x] Prove dynamic per-frame data by rotating the existing triangle without backend-specific Game code through fixed-capacity `setVertexBytes` recording; do not recreate immutable buffers each frame.
- [ ] Let real `Pixl2D` needs determine sprites, batching, 2D transforms, cameras, and texture workflows.
- [ ] Let real `Pixl3D` needs determine meshes, materials, depth, 3D transforms, cameras, and lighting.
- [ ] Keep shared, dimension-independent facilities in `PixlGraphics`.
- [ ] Keep all GPU concepts and platform implementations dimension-agnostic in `PixlPlatform`.
- [ ] Add reusable internal upload-ring and readback lifetimes before exposing stage-specific dynamic bytes, buffer writes, or copy commands. Do not expose `upload` as game-facing render intent.

## Guiding Constraints

- Obvious, intuitive, and fast APIs.
- Multi-core capable by design; parallelism must earn its synchronization and scheduling costs.
- No avoidable allocation or dynamic dispatch in hot paths.
- Metal-first API development, modern-DirectX alignment, then adapter-owned WebGPU/Vulkan lowering.
- Playable Game targets remain the proof of every abstraction.
