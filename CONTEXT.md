# PixlPlatform Vocabulary

PixlPlatform is the lowest platform-agnostic GPU layer in Pixl. Its public interface follows Metal's direct encoder/resource-slot model, with modern DirectX used as a second alignment reference. WebGPU and Vulkan must implement the same capabilities, but their bind groups, descriptor sets, layout declarations, and pipeline variants are adapter machinery unless a future cross-platform requirement proves otherwise.

This is not a legacy OpenGL/WebGL state-machine abstraction. It is dimension-agnostic; 2D and 3D meaning belongs in higher layers.

## Platform Mapping

| PixlPlatform | Metal | DirectX 12 | WebGPU adapter | Vulkan adapter |
| --- | --- | --- | --- | --- |
| `Platform` | runtime + `MTKView` | runtime + swapchain | runtime + canvas context | runtime + swapchain |
| `Device` | `MTLDevice` | `ID3D12Device` | `GPUDevice` | `VkDevice` |
| `Queue` | `MTLCommandQueue` | `ID3D12CommandQueue` | `GPUQueue` | `VkQueue` |
| `Frame` | recorded command-buffer input | recorded command-list input | command-encoder input | command-buffer input |
| `Buffer` | `MTLBuffer` | `ID3D12Resource` | `GPUBuffer` | `VkBuffer` |
| `Texture` | `MTLTexture` | `ID3D12Resource` | `GPUTexture` | `VkImage` / `VkImageView` |
| `Sampler` | `MTLSamplerState` | sampler descriptor | `GPUSampler` | `VkSampler` |
| `RenderPipeline` | `MTLRenderPipelineState` | `ID3D12PipelineState` | `GPURenderPipeline` variant | `VkPipeline` variant |
| `VertexLayout` | `MTLVertexDescriptor` | `D3D12_INPUT_LAYOUT_DESC` | `GPUVertexBufferLayout` | `VkVertexInput*` descriptions |
| `RenderPassDescriptor` | `MTLRenderPassDescriptor` | RTV/DSV pass configuration | `GPURenderPassDescriptor` | dynamic-rendering/pass configuration |
| `RenderPassEncoder` | `MTLRenderCommandEncoder` | graphics command list methods | `GPURenderPassEncoder` | `vkCmd*` recording |
| `setRenderPipeline` | `setRenderPipelineState` | `SetPipelineState` | `setPipeline` | `vkCmdBindPipeline` |
| `setVertexBuffer` | `setVertexBuffer` | root/descriptor or vertex-buffer binding | vertex buffer or internal bind group | vertex buffer or internal descriptor set |
| `setFragmentTexture` | `setFragmentTexture` | descriptor table/root binding | internal bind group | internal descriptor set |
| `setFragmentSampler` | `setFragmentSamplerState` | sampler descriptor table | internal bind group | internal descriptor set |
| `drawPrimitives` | `drawPrimitives` | `DrawInstanced` | `draw` | `vkCmdDraw` |
| `drawIndexedPrimitives` | `drawIndexedPrimitives` | `DrawIndexedInstanced` | `setIndexBuffer` + `drawIndexed` | `vkCmdBindIndexBuffer` + `vkCmdDrawIndexed` |
| `RenderTarget` | texture + mip/slice | resource/view | `GPUTextureView` | `VkImageView` |

WebGPU/Vulkan may require adapter-owned grouping or pipeline variants to implement a direct Pixl encoder command. That does not change the public vocabulary.

## Core Objects

`Device`
: Logical GPU access. Creates queues and resources. Pooled resources are explicitly destroyed through the same device.

`Queue`
: Submission lane for recorded `Frame` work.

`Platform`
: Frame-presentation seam. Exposes the device, acquires a frame-scoped `Drawable`, and presents a recorded `Frame`.

`Frame`
: Reusable, fixed-capacity, allocation-free recording storage for ordered passes and primitive encoder commands. Public callers cannot append internal pass/command values directly.

## Game Lifecycle and Time

`GamePhase`
: Coarse platform lifecycle: `background`, `active`, or `inactive`. Loading and preparation remain game-owned state. Phase transitions are delivered once through `Game.didEnter(_:context:)`.

`GameContext`
: Stable runtime-owned reference supplied during game initialization and as the final argument to every lifecycle, update, and render callback. It exposes the platform, drawable format, audio, assets, and mutable time scale; it does not expose all startup `RenderSettings`. `Game.didEnter`, `fixedUpdate`, and `update` mutate the game value directly, while `render` is read-only.

`GameContext.timeScale`
: Nonnegative simulation-time multiplier. `0` suppresses fixed updates while presentation updates and rendering continue. Audio and unscaled time remain independent. Changes made by a callback affect the next presentation schedule, allowing `UpdateTime.unscaledDelta` to drive pause and slow-motion ramps.

`FixedTime.delta`
: Fixed simulation step after game time scaling determines whether a tick occurs.

`UpdateTime.delta`
: Clamped presentation delta multiplied by `GameContext.timeScale`.

`UpdateTime.unscaledDelta`
: The same clamped presentation delta before `GameContext.timeScale`. Lifecycle fades and other work that must continue while simulation is paused use this value.

Pixl has no dependency on or re-export of `PixlConcurrency`; games may depend on that standalone package directly when they need explicit lanes.

## Keyboard Input

`Keyboard`
: Platform-owned physical keyboard state exposed through `Platform` and `GameContext`. `contains(_:)` reads current down-state in constant time. `events` is the ordered, contiguous transition batch published for the current presentation frame; `key(_:phase:)` and `contains(_:phase:)` use constant-time per-key/per-phase lookup.

`Key`
: Portable physical key position, independent of produced character and active keyboard layout. macOS translates `NSEvent.keyCode`; the browser translates `KeyboardEvent.code`.

`Key.Event`
: One `.down` or `.up` transition with the complete `Key.Modifiers` snapshot. The first down has `isRepeat == false`; native auto-repeat downs have `isRepeat == true` and coalesce to at most one event per key per frame. Current held state remains separate from event phase.

Keyboard event storage is runtime-owned, fixed-capacity, contiguous, and double-buffered. Native callbacks append into pending storage; presentation swaps it into the published frame without copying or allocating. At most one event per key and phase is retained each frame, so capacity derives from the closed `Key` vocabulary rather than game settings. Focus loss synthesizes `.up` for every down key before clearing state. `Keyboard.isFocused` reports keyboard focus.

## Resource Ownership

`ResourceID`
: Package-visible 64-bit generational handle: 32-bit direct slot index plus 32-bit generation. Generation zero is reserved. Stale handles fail lookup after destruction/reuse. A phantom generic tag was measured and rejected after roughly 55% release lookup regression across the package seam.

`ResourcePool`
: Package-level fixed-capacity native-resource storage. It uses contiguous manually managed slots, O(1) lookup/removal, generation validation, and an intrusive free list. It allocates only at initialization and contains no internal synchronization.

`Buffer`, `Texture`, `Sampler`, `RenderPipeline`
: Copyable opaque handles plus deliberate public metadata where applicable. Creation inserts a native resource into its backend pool. `Device.destroy` invalidates the handle immediately and returns the slot for reuse. Copies of a destroyed handle are stale. Backends remain responsible for deferring native reclamation when already-submitted GPU work still references that resource.

`Drawable`
: Noncopyable frame-scoped presentable texture. Presentation consumes it. Its transient texture is platform-owned and must not be explicitly destroyed by game code.

Release `PixlPlatform` builds use `-enable-cmo-everything`, allowing concrete package adapters to specialize hot package-private generic code such as `ResourcePool<Value>`.

## Buffers and Textures

`BufferDescriptor`
: Describes an entire buffer allocation: byte size, allowed usage roles, and memory intent.

`BufferMemory`
: Explicit allocation intent: `.gpuOnly`, `.cpuVisible`, or `.gpuToCPU`. It is intent, not a promise of identical physical memory on every backend.

`BufferUsage`
: Allowed roles such as vertex, index, uniform, storage, copy source, and copy destination.

`TextureDescriptor`
: Describes an entire texture allocation. Dimension/type, mip, cube, and richer array semantics remain an explicit future design gate.

`Device.makeTexture(copying:descriptor:bytesPerRow:)`
: Creates a texture with initial owned pixel bytes. Metal stages rows into an aligned transfer buffer and blits into private texture storage before publishing the handle.

`TextureWriter`
: Optional backend-owned asynchronous access to one existing texture. It supports event-driven same-size content replacement without changing the public texture handle or touching frame recording. Metal orders writes and rendering through the same command queue. Backends that do not support live texture writes return no writer.

`SamplerDescriptor`
: Portable filtering and address-mode state. Samplers are pooled opaque resources, independent of textures.

`RenderTarget`
: Texture view shape selecting a texture, mip level, and array layer.

## Platform Asset Capability

`AssetSource`
: Rooted platform capability that reads bytes for a validated logical `AssetPath`. Its optional `AsyncStream<AssetChange>` reports file-level source changes without imposing asset formats or reload policy on the platform layer.

macOS resolves the game-provided asset path relative to the Game package that declares `AssetSettings`. `AssetSettings` captures that declaration's `#filePath`; the adapter removes its `/Sources/...` suffix without searching the filesystem, then appends the configured path. Absolute paths bypass package-relative resolution. macOS reads directly from that directory and monitors recursive file changes with FSEvents. Pixl owns decoding, caching, dependency decisions, and reload failure policy. Same-size texture changes are written asynchronously through the platform writer; rendering does not poll for changes.

`Assets.load(texture:)` and `Assets.load(sound:)` throw `AssetError`. Required startup assets therefore fail explicitly instead of becoming optional values with logged errors.

Browser packaging copies `Game/Assets`, generates a manifest, and preloads those files before starting WASM. `PixlWasmPlatform` exposes the resulting in-memory bytes through the same synchronous `AssetSource` contract used by Pixl during game initialization. Browser builds do not monitor assets for changes.

PNG structure parsing and pixel decoding are shared Swift code in `PixlGraphics`. It uses the vendored Apple Swift Binary Parsing core and a Pixl-owned zlib/DEFLATE, scanline-filter, colour, transparency, and Adam7 implementation. Platform image frameworks are not part of PNG decoding.

## Portable Audio

`AudioSettings`
: Startup-only fixed capacities. `maxSoundCount` is the total number of resident `Sound` resources, `maxVoiceCount` is the simultaneous active native-voice limit, and `maxBusCount` is the number of game-created flat buses. Prepared playback controllers consume no voice slot. The master output is separate and does not consume a bus slot.

`Sound`
: Opaque generational handle for decoded resident samples. Pixl currently decodes WAV in shared Swift code into planar `Float32`, mono or stereo. Supported WAV payloads are 8/16/24/32-bit integer PCM and 32-bit IEEE float. Compressed formats and streaming sources remain future additions.

`Playback`
: Reusable reference controller created by `Audio.prepare` without starting or allocating a native voice. It strongly retains the shared audio controller and owns `play`, `pause`, `stop`, `volume`, `pan`, `rate`, `loop`, and `bus`. Initial configuration is volume `1`, pan `0`, rate `1`, looping disabled, and the master bus. `play` starts a new voice or resumes a paused live voice; `pause` preserves its playhead; `stop` destroys the active voice but leaves the controller reusable, and controller deinitialization also stops its active voice. Volume, pan, and rate changes update both stored configuration and a live voice. Loop and bus configuration apply when a new voice starts. Pitch shifts naturally with rate. A finished voice is retired lazily when controlled or when voice capacity is needed, so there is no per-frame reaper.

`Bus`
: Nonoptional flat routing target with an owned volume property initially set to `1`. Every prepared playback defaults to `Audio.masterBus`; game-created buses come from throwing, nonoptional `Audio.makeBus()`. Games assign semantic meaning such as music, effects, or voices, persist their volume values, then recreate buses and restore those values on launch; bus identities are runtime-only. Backends may still represent direct master routing with an internal absent handle. Buses feed the master output; nested graphs and effects are not part of the current contract.

`AudioDevice`
: Portable low-level resource/playback boundary. Shared `AudioEngine` creates prepared controllers and owns active handles, capacity, validation, buses, voice lifetime, control values, master volume, and sound replacement. Master volume starts at `1`. Concrete adapters only create native sample/voice/bus resources and perform primitive playback operations when a controller becomes active. Controller getters use portable stored state and never synchronously query a native audio graph. Metal uses AVFAudio; the browser uses Web Audio.

`SoundWriter`
: Optional backend-owned replacement/invalidation capability for a stable `Sound` handle. macOS asset changes arrive from the existing recursive event stream; Pixl coalesces each per-path event burst, reads, and decodes off the game loop. A valid content replacement restarts active voices from the beginning with their existing playback controllers and controls; paused voices remain paused. Removal immediately stops and retires active voices but retains prepared controllers and configuration. Their next `play` throws `AudioError.resourceUnavailable(.sound)` until valid content reappears, then explicitly playing uses the replacement. Invalid replacement data retains the last valid sound. Browser-packaged assets remain an immutable build-time snapshot for now.

Native completion handlers only set an atomic flag. Cleanup is demand-driven; completion performs no task creation, logging, allocation, or engine lock acquisition.

The macOS adapter owns one private serial `.utility` QoS audio-control queue. It creates and operates every AVFAudio engine, buffer, mixer, player, and varispeed node on that queue; game/render callers only perform fixed-capacity handle bookkeeping and enqueue commands. A native bus mixer is attached when created but connects downstream only while at least one voice is connected; its final voice removal disconnects it again. Audio hardware configuration notifications enqueue recovery on the same queue, so preparing or restarting a stopped engine never blocks frame work. Core Audio owns the real-time rendering thread. No route polling runs in the game loop.

Web Audio already separates its control and rendering threads internally. The current single-threaded WASM adapter issues lightweight `AudioContext` graph-control calls from the browser control thread; a stricter separation of those calls requires a future AudioWorklet/worker messaging backend. Browsers may initially suspend the context until a user gesture. Pixl keeps the game running and retains logical voice timelines while output is unavailable, then starts or resumes their sources when the context becomes active.

## Shaders and Pipelines

`ShaderFunction`
: Portable shader entry-point name. `PixlGraphics` publishes built-in names as static members on this type. It carries no artifact or backend-library ownership.

Concrete adapters own their built-in shader sources. SwiftPM compiles `PixlMetalPlatform`'s `.metal` files into the target's default library; `PixlWasmPlatform` embeds its WGSL source. Pipeline creation resolves `ShaderFunction.name` against that adapter-owned library or module. Pixl currently has no public custom-shader loading or registration API.

`RenderPipelineDescriptor`
: Startup description of shader functions, vertex input layout, and attachment format. Exact primitive topology is not pipeline state in Pixl's Metal-first interface; it is supplied to `drawPrimitives`. Backends that require topology at pipeline creation own/cache the corresponding native variants.

`VertexLayout`
: Fixed-capacity startup description of vertex-buffer streams and shader attributes. It describes GPU byte layout only; games own their Swift vertex types and bytes.

## Render Recording

`RenderPassDescriptor`
: Attachment/load/store description used to begin one render pass. It contains no frame-storage bookkeeping.

`RenderPassEncoder`
: Metal-shaped public recorder. Callers set pipeline/resource state and then issue draws. Current commands include pipeline, vertex buffer/bytes, fragment texture/sampler bindings, and primitive/indexed draws.

`RenderCommand`
: Package-only compact command representation stored by `Frame`. It is not public game vocabulary. Resource commands store `ResourceID` rather than copying full descriptors into every recorded command.

`PrimitiveTopology`
: Exact primitive interpretation supplied to `drawPrimitives`: point, line, line strip, triangle, or triangle strip.

`IndexType`
: Portable index element width: `uint16` or `uint32`. `drawIndexedPrimitives` takes the index buffer directly, matching Metal. WebGPU, Vulkan, and DirectX adapters bind/cache that buffer privately before their indexed draw command.

Commands for a pass must be recorded contiguously. `Frame` preallocates command storage from startup-only `RenderSettings.frameCommandCapacity`; recording performs no allocation or dynamic dispatch.

## Dynamic Data and Resource Slots

Pixl's public direction is stage/resource-specific encoder intent, matching Metal: vertex/fragment buffers, bytes, textures, and samplers; compute encoders imply the compute stage. Public bind groups and dynamic-offset flags are not current Pixl concepts.

`setVertexBytes` copies at most 4 KiB immediately into fixed-capacity `Frame` byte storage. Metal lowers it to native inline bytes. WebGPU copies those recorded bytes through a fixed-capacity adapter-owned uniform buffer and one reusable dynamic-offset bind group. Larger or persistent data uses buffers instead.

Dynamic CPU-to-GPU transfer storage, upload rings, WebGPU bind groups, Vulkan descriptor sets, and DX12 descriptor allocation are private adapter mechanisms. Before adding larger buffer-write/copy APIs, define GPU-completion retirement and readback lifetime. Do not expose a generic per-call write API that allocates staging resources or synchronizes CPU/GPU execution.

## Required Future Depth

Compute is required and must use the same encoder-command direction: compute pipeline state, buffer/texture resource slots, access modes, and dispatch commands. Compute output must feed later render passes in the same frame.

Other explicit gates include WebGPU texture/sampler lowering, multiple color attachments, depth/stencil, blending, multisampling, richer texture dimensions/mips, copy commands, dynamic bytes, readback, and profiling counters. Add each through playable Game needs without widening existing modules into shallow configuration bags.
