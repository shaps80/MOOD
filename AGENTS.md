# PixlPlatform Agent Notes

PixlPlatform is the platform-agnostic API boundary for Pixl. Its current surface is the lowest graphics/GPU layer, expressed as Swift-only types and protocols implemented by platform targets such as Metal, WebGPU, Vulkan, and DirectX 12.

## Collaboration Rules

- Discuss design first unless the user explicitly asks to implement, edit, fix, or change code.
- Keep responses short and one topic at a time when discussing architecture.
- The user wants to write most implementation code personally. Prefer explaining the smallest next shape instead of generating large code blocks.
- Do not introduce platform imports in this library.
- Do not add legacy WebGL/OpenGL fallback language or abstractions.
- Prefer Metal-shaped GPU concepts and validate them against modern DirectX.

## Current Design Direction

The lowest layer is not a 2D renderer. It is a modern GPU abstraction for resources, pipelines, passes, encoder commands, frames, and profiling data.

2D and 3D conveniences should live above this layer. The GPU layer should remain dimension-agnostic.

Pixl's near-term product goal is a Raylib-like time-to-first-game without adopting Raylib's OpenGL-shaped architecture. Focus the cross-platform foundations on rendering, raw input, audio, texture/sprite asset loading, and an obvious startup path. Convenience APIs belong above those foundations.

Entities, spawning, and world ownership are game concerns, not engine concerns. Push back if they begin entering Pixl's engine or platform scope. Physics and particle simulation are also separate future libraries that may consume Pixl rendering; they are not part of the current foundation work.

`PixlText` remains part of the intended game-facing stack. `PixlUI` may later support debugging and tooling, but is not a current priority.

Do not put a camera system into `PixlPlatform` or concrete platform adapters. Do ensure their rendering and data APIs are sufficiently general that higher layers can build sophisticated 2D and 3D camera systems without backend changes or platform knowledge.

Primary API-design reference:

- Metal

Secondary alignment reference:

- DirectX 12

Adapters that must lower the same portable contract later:

- WebGPU
- Vulkan

Keep the public `PixlPlatform` interface close to Metal's direct encoder/resource-slot model. Do not expose WebGPU bind groups, Vulkan descriptor sets, or their layout rules merely because an adapter needs them. WebGPU/Vulkan adapters own descriptor grouping, caching, and pipeline variants internally unless a future cross-platform requirement proves that machinery belongs in the public interface.

During the current API refocus, implement and validate `PixlPlatform` with `PixlMetalPlatform` first. Do not preserve a questionable public abstraction solely to keep `PixlWasmPlatform` compiling. Adapt WASM only after the portable API is accepted through the Metal Game proof.

Avoid designing around:

- OpenGL
- WebGL
- Legacy state-machine APIs

## Current Progress

The first vertical slice is intentionally small: describe a frame with ordered passes and make resource ownership explicit before adding draw commands, pipelines, or bindings.

Implemented/decided so far:

- `Frame` owns reusable fixed-capacity contiguous recorded-pass and command storage. Runtime resets it each redraw; public callers record only through pass encoders; platform adapters iterate package-visible storage directly.
- `Frame.beginRenderPass` accepts a `RenderPassDescriptor` and returns a value-type `RenderPassEncoder`. Its public interface follows Metal: set pipeline/resource state, then issue primitive draws. Commands for a pass must be recorded contiguously.
- Public `DrawCommand` and `Pass` values were removed. They exposed frame-storage implementation and would have grown into shallow bags of every future resource. Package-only `RenderCommand` storage records compact `ResourceID` payloads instead.
- Exact `PrimitiveTopology` belongs to `RenderPassEncoder.drawPrimitives`, matching Metal and DirectX. Backends where topology is pipeline state must lower/cache pipeline variants internally.
- `RenderPassEncoder.setVertexBytes` immediately copies up to 4 KiB of `BitwiseCopyable` or raw bytes into fixed-capacity `Frame` storage. Metal lowers it to native `setVertexBytes`; adapter-specific transfer storage remains private.
- `PixlConcurrency` is a standalone sibling package containing an optional lane-based execution layer. Pixl does not depend on or re-export it; games may depend on it directly. Keep it platform-agnostic and independent of concrete platform targets.
- `VertexLayout` owns fixed-capacity contiguous vertex-buffer and attribute descriptions. It defines GPU byte layout only; games retain ownership of their vertex Swift types and bytes.
- `RenderPassDescriptor` currently owns one `ColorAttachment`. Compute remains a required future encoder, but empty public compute/pass placeholders must not imply implemented support.
- `ColorAttachment` owns `RenderTarget`, `LoadAction`, and `StoreAction`.
- `RenderTarget` is a texture view shape: texture plus mip level and array layer. It is not a `screen` enum.
- `Texture` is an opaque backend resource handle plus immutable `TextureDescriptor`.
- `Texture.id` is a package-visible `ResourceID`, so higher layers can hold textures but cannot see or mint backend handles.
- `Buffer` follows the same opaque-handle model as `Texture`. `BufferMemory` requires explicit `.gpuOnly`, `.cpuVisible`, or `.gpuToCPU` intent. `Device.makeBuffer` supports fixed-size allocation or an initial copy from `UnsafeRawBufferPointer`; buffer capacity is startup-only `RenderSettings` configuration.
- Pooled `Buffer`, `Texture`, `Sampler`, and `RenderPipeline` handles have explicit `Device.destroy` operations. Destroy invalidates the generational handle immediately; adapters may defer native reclamation until already-submitted GPU work no longer references the resource.
- `ShaderFunction` is only a portable entry-point name. `PixlGraphics` exposes its built-in functions as `.vertex` and `.fragment`.
- Concrete adapters own their built-in shader sources directly: SwiftPM compiles `PixlMetalPlatform`'s `.metal` files into its default library, while `PixlWasmPlatform` embeds its WGSL. There is no public shader object, registry, library abstraction, generator executable, or build plugin.
- `Texture.init` and `ResourceID.init` are `package`, because platform backends live in the same Swift package while games/higher abstractions do not.
- `Platform` is the platform-neutral frame boundary. It exposes a device, acquires a frame-scoped `Drawable`, and presents a `Frame` to that drawable.
- `Drawable` owns a frame-scoped presentable texture. It is noncopyable and consumed by `Platform.present`.
- `Game` is the game-facing lifecycle. `GameRuntime<G: Game>` owns the concrete mutable game and platform-neutral `Loop`, implements `PlatformGame`, and is what concrete platform runtimes receive. Every fixed-update, update, and render callback receives the stable `GameContext`. `GameContext.timeScale` affects simulation delta while `UpdateTime.unscaledDelta` continues during pause. Game initialization still runs after the platform and built-in shaders exist, allowing immutable startup resources without optional storage.
- `GameRuntime` has no asset polling or reload work in its presentation callback. Texture and sound reloads are event-driven and remain outside simulation and render traversal.
- Public resource creation should flow through `Device`, not direct initializers.
- `DeviceError` is the public error surface for device/resource creation failures. Keep texture-specific detail as cases inside `DeviceError` rather than creating separate texture errors for now.
- `PixlMetalPlatform` has begun as the first concrete platform target. `MetalDevice` owns fixed-capacity buffer, texture, sampler, and pipeline pools whose capacities are supplied explicitly at initialization. GPU-only buffers and initial texture pixels use staging/blit uploads.
- `MetalDevice` also owns fixed-capacity `ResourcePool<MetalRenderPipeline>` storage. Public `RenderPipeline` is an opaque `ResourceID` handle, so encoder commands resolve native state directly without existential storage or per-draw type casts.
- `MetalDevice.makeTexture` supports empty allocation or initial owned pixel bytes, maps `TextureDescriptor` to `MTLTextureDescriptor`, and returns a package-minted `Texture`.
- `RenderPassEncoder` records fragment texture and sampler bindings. Metal lowers them directly; WebGPU lowering remains follow-up work.
- `MetalDevice.makeQueue` creates a `MetalQueue` sharing the device's resource pools.
- `MetalQueue.submit` resolves compact resource handles and lowers the recorded command stream almost one-for-one to `MTLRenderCommandEncoder`, then commits the command buffer.
- `PixlMetalPlatform.run(_:)` is the single public macOS runtime entry point. It owns the AppKit/MTKView window runtime and its Metal device; `Pixl.run(_:)` reaches it through Pixl's macOS-conditioned platform dependency.
- `PixlWasmPlatform.run(_:)` is the WASM/browser runtime entry point. It lowers Metal-shaped commands through cached WebGPU pipeline variants and a fixed-capacity internal uniform buffer/dynamic-offset bind group; those WebGPU concepts remain private to the adapter.
- The standalone `PixlConcurrency` package supports WASM independently. The supported single-threaded WASI SDK reports one available lane and uses its single-lane execution path; Pixl itself does not link it.
- `MetalPlatform` imports the current MTKView drawable into fixed-capacity pools for one frame, submits the frame, schedules `CAMetalDrawable` presentation, then retires those transient handles. The capacities come from game-provided `RenderSettings` at startup.
- `GameSettings` configures startup window/runtime values such as title, initial resolution, resizability, and preferred frame rate. `Game` supplies it with a default implementation.
- `PixlPlatform.AssetSource` is a rooted byte-read capability with optional asynchronous file changes. `PixlMetalPlatform` supplies a project-relative directory source backed by recursive file-level FSEvents.
- `Pixl.Assets` owns PNG decoding, caching, stable `TextureAsset` identities, background reload processing, and last-good retention. Same-size texture changes write asynchronously into the existing texture through a backend-owned `TextureWriter`; dimension changes are rejected for now. Game-facing texture and sound loads throw `AssetError` instead of returning optional assets.
- `PixlPlatform.AudioEngine` owns fixed-capacity resident sounds, active voices, flat buses, portable playback semantics and control values, stable sound replacement, and sound availability. `Audio.prepare` creates a reusable `Playback` controller without allocating or starting a native voice. `Playback` strongly retains its shared controller and owns `play`, `pause`, `stop`, `volume`, `pan`, `rate`, `loop`, and nonoptional `bus`; `Bus` owns its volume and defaults to the master bus. `play` throws only when it must create an active voice. Removal stops matching voices but retains prepared controllers and their configuration; valid in-place content changes restart active voices while preserving playback identity and controls. Native completion handlers only set atomic flags; finished voices are reclaimed on demand without a frame-time reaper.
- `Pixl` decodes mono/stereo WAV into planar `Float32`, loads it as `SoundAsset`, and hot-reloads it through coalesced recursive asset events. Metal lowers the portable contract through AVFAudio entirely on a private serial `.utility` queue; game/render callers only enqueue commands, and output configuration recovery cannot block frame work. The browser lowers through Web Audio, whose rendering thread is browser-owned while current graph-control calls remain on the single-threaded WASM control thread. Native graph types remain adapter-private and packaged browser assets remain static until a development-server change channel exists.
- Metal implementation types and protocol witnesses remain internal. Keep the cross-platform public API in `PixlPlatform`; expose only the smallest deliberate platform construction boundary from `PixlMetalPlatform`.

## Naming

Use unprefixed Swift names. The module is the namespace.

Examples:

- `Device`, not `GPUDevice`
- `Queue`, not `GPUQueue`
- `CommandBuffer`, not `GPUCommandBuffer`
- `Buffer`, not `GPUBuffer`
- `Texture`, not `GPUTexture`
- `Sampler`, not `GPUSampler`
- `Frame`, not `GPUFrame`

Concrete names are currently represented by the file names in this folder.

## Context File

Read `context.md` before making or proposing changes to this layer. It contains the agreed vocabulary and backend mapping table.

Keep `context.md` updated when vocabulary decisions change.

Read `ROADMAP.md` for cross-session architectural workstreams and unresolved decision gates. Keep milestone progress there rather than turning `AGENTS.md` into a task list.

## Performance and Profiling

Performance is a first-class design constraint.

Pixl and PixlPlatform targets default to Swift 6 nonisolated code with `.defaultIsolation(nil)`. Concrete platform targets add actor isolation only where their native UI APIs require it; do not impose a platform UI actor on the portable `PixlPlatform` contract.

The `PixlPlatform` target enables provider-side aggressive cross-module optimization with `-enable-cmo-everything` in release builds. This serializes its package-private implementations so ordinary optimized consumers such as `PixlMetalPlatform` can specialize hot generic code such as `ResourcePool<Value>`. Do not combine it with `-cross-module-optimization`; that selects a less aggressive serialization mode and restores generic calls. Add the setting to another provider target only when that target gains hot cross-module implementation code.

Run `.scripts/test` from the repository root for WASM-only `PixlConcurrency` and `ResourcePool` correctness through Swift Testing and WasmKit. Native ResourcePool performance coverage lives directly in its XCTest file and is run from the `PixlPlatform` package when needed.

Build the browser Game package with `.scripts/_package-web`; serve it with `.scripts/serve`. Both default to the sibling `Game` package and product.

Accepted performance baselines belong in `PERF.md` beside this file and `CONTEXT.md`, not as comments in test source. When the user mentions profiling, performance measurements, benchmark results, or baselines, read `PERF.md` before reasoning about or running profiling work. Update it only with accepted recorded results, and keep each record explicit about the system being profiled, workload, runtime, toolchain, and warm-up method.

The library should support platform-agnostic CPU-side profiling from the beginning:

- per-frame timings
- per-pass timings
- draw counts
- dispatch counts
- vertex/index counts
- bytes uploaded
- resource binding counts
- culling/batching counters in higher layers later

GPU timings may be backend-specific later, but CPU-side metrics should be Swift-only and portable.

## Compute

Compute must be considered now, not deferred.

The GPU layer should include concepts for:

- `ComputePipeline`
- `ComputePass`
- dispatch commands
- storage buffers
- writable/read-write textures
- resource access modes

Compute output should be able to feed later render passes in the same frame.

## Open Design Decisions

- Before adding public dynamic-byte, buffer-write, or copy commands, design reusable frame upload-ring and readback lifetimes. `Upload` describes private transfer machinery, not game-facing render intent; public calls should remain stage/resource specific, such as Metal's `setVertexBytes` family.
