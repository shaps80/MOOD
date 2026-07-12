# PixlPlatform Agent Notes

PixlPlatform is the platform-agnostic API boundary for Pixl. Its current surface is the lowest graphics/GPU layer, expressed as Swift-only types and protocols implemented by platform targets such as Metal, WebGPU, Vulkan, and DirectX 12.

## Collaboration Rules

- Discuss design first unless the user explicitly asks to implement, edit, fix, or change code.
- Keep responses short and one topic at a time when discussing architecture.
- The user wants to write most implementation code personally. Prefer explaining the smallest next shape instead of generating large code blocks.
- Do not introduce platform imports in this library.
- Do not add legacy WebGL/OpenGL fallback language or abstractions.
- Prefer modern-facing GPU concepts aligned with Metal and WebGPU.

## Current Design Direction

The lowest layer is not a 2D renderer. It is a modern GPU abstraction for resources, pipelines, bindings, passes, commands, frames, and profiling data.

2D and 3D conveniences should live above this layer. The GPU layer should remain dimension-agnostic.

Primary reference backends:

- Metal
- WebGPU

Future alignment backends:

- Vulkan
- DirectX 12

Avoid designing around:

- OpenGL
- WebGL
- Legacy state-machine APIs

## Current Progress

The first vertical slice is intentionally small: describe a frame with ordered passes and make resource ownership explicit before adding draw commands, pipelines, or bindings.

Implemented/decided so far:

- `Frame` owns reusable fixed-capacity contiguous `Pass` storage. Runtime resets it each redraw; game code records through `append`; platform backends iterate it directly.
- `Frame.beginRenderPass` returns a value-type encoder that appends to its fixed-capacity draw-command storage. This keeps per-frame draw recording allocation-free; draw commands for a pass must be recorded contiguously.
- `PixlExec` is a package-internal, platform-agnostic target reserved for Pixl's lane-based multi-core execution layer. Do not expose it to games or make it depend on concrete platform targets unless that direction is explicitly revisited.
- `VertexLayout` owns fixed-capacity contiguous vertex-buffer and attribute descriptions. It defines GPU byte layout only; games retain ownership of their vertex Swift types and bytes.
- `Pass` currently supports `.render(RenderPass)` and `.compute(ComputePass)`.
- `RenderPass` owns a `ColorAttachment`.
- `ColorAttachment` owns `RenderTarget`, `LoadAction`, and `StoreAction`.
- `RenderTarget` is a texture view shape: texture plus mip level and array layer. It is not a `screen` enum.
- `Texture` is an opaque backend resource handle plus immutable `TextureDescriptor`.
- `Texture.id` is a package-visible `ResourceID`, so higher layers can hold textures but cannot see or mint backend handles.
- `Buffer` follows the same opaque-handle model as `Texture`. `BufferMemory` requires explicit `.gpuOnly`, `.cpuVisible`, or `.gpuToCPU` intent. `Device.makeBuffer` supports fixed-size allocation or an initial copy from `UnsafeRawBufferPointer`; buffer capacity is startup-only `RenderSettings` configuration.
- `Shader` owns immutable compiled shader bytes; `ShaderLibrary` is an opaque backend-native reference object created from it. Shader libraries are retained by normal object lifetime, not a resource pool or `RenderSettings` capacity. `PixlShaderPlugin` lives in PixlPlatform and currently attaches to PixlGraphics to generate its built-in shader resource; future Game-authored shader resources can attach the same plugin to their Game target.
- `ShaderCatalogue.default` is PixlGraphics' generated built-in shader and Pixl registers it automatically before `PlatformGame` initialization. Generated `Shaders.vertex` and `Shaders.fragment` are game-facing entry-point values. `Platform.shaders` is the platform-owned `ShaderRegistry`; games append their own shaders from `init(platform:)` without managing shader-library lifetime or platform resource loading.
- `Texture.init` and `ResourceID.init` are `package`, because platform backends live in the same Swift package while games/higher abstractions do not.
- `Platform` is the platform-neutral frame boundary. It exposes a device, acquires a frame-scoped `Drawable`, and presents a `Frame` to that drawable.
- `Drawable` owns a frame-scoped presentable texture. It is noncopyable and consumed by `Platform.present`.
- `PlatformGame` is the lower-level render capability that concrete platform runtimes receive. Its throwing `init(platform:)` runs after the concrete platform and built-in shaders exist, allowing games to create immutable startup resources without optional storage. It records into the runtime-owned `Frame` for the runtime-provided final `RenderTarget`; `Game` inherits it, so game packages use `Game` rather than this protocol directly.
- Public resource creation should flow through `Device`, not direct initializers.
- `DeviceError` is the public error surface for device/resource creation failures. Keep texture-specific detail as cases inside `DeviceError` rather than creating separate texture errors for now.
- `PixlMetalPlatform` has begun as the first concrete platform target. `MetalDevice` owns fixed-capacity `ResourcePool<MTLBuffer>` and `ResourcePool<MTLTexture>` storage whose capacities are supplied explicitly at initialization. `.gpuOnly` initial buffer data uses a private Metal buffer plus staging/blit upload; `.cpuVisible` and `.gpuToCPU` currently use shared storage.
- `MetalDevice` also owns fixed-capacity `ResourcePool<MetalRenderPipeline>` storage. Public `RenderPipeline` is an opaque `ResourceID` handle, so draw encoding resolves native state directly without existential storage or per-draw type casts.
- `MetalDevice.makeTexture` maps `TextureDescriptor` to `MTLTextureDescriptor`, inserts the created `MTLTexture` into that pool, and returns package-minted `Texture`.
- `MetalDevice.makeQueue` creates a `MetalQueue` sharing the device's texture pool.
- `MetalQueue.submit` resolves render targets, pipelines, and vertex buffers for ordered render passes, then encodes Metal primitive draws and commits the command buffer.
- `PixlMetalPlatform.run(_:)` is the single public macOS runtime entry point. It owns the AppKit/MTKView window runtime and its Metal device; `Pixl.run(_:)` reaches it through Pixl's macOS-conditioned platform dependency.
- `MetalPlatform` imports the current MTKView drawable into fixed-capacity pools for one frame, submits the frame, schedules `CAMetalDrawable` presentation, then retires those transient handles. The capacities come from game-provided `RenderSettings` at startup.
- `GameSettings` configures startup window/runtime values such as title, initial resolution, resizability, and preferred frame rate. `Game` supplies it with a default implementation.
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

Resource-pool checks and benchmarks have one platform-neutral source of truth in `PixlPlatformTestSupport`. The XCTest target is a native/Xcode adapter. Run `../.scripts/test` from this package, or `.scripts/test` from the repository root, for the release comparison: native first, then WASM/WASI through the Swift SDK and WasmKit. Pass `native` or `wasm` to run one side only. Pass `metal` for the native-only default-capacity `ResourcePool<MTLTexture>` runtime scenario; it uses distinct real 1×1 Metal textures and measures resolution, transient drawable churn, and rare texture replacement without GPU allocation inside timed sections.

For real browser measurements, run `.scripts/browser-test chrome` or `.scripts/browser-test safari` from the repository root. The browser runner waits one second, runs one complete discarded warm-up suite, then renders the measured report in the selected browser. Treat those results as the Web performance authority; WasmKit is a fast local portability and regression baseline, not a browser-performance proxy.

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

- Before adding buffer writes or copies, design reusable frame upload-ring and readback lifetimes. Do not add a naïve generic write API that allocates staging buffers or synchronizes CPU/GPU work per call.
