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

- `Frame` owns ordered `[Pass]`.
- `Pass` currently supports `.render(RenderPass)` and `.compute(ComputePass)`.
- `RenderPass` owns a `ColorAttachment`.
- `ColorAttachment` owns `RenderTarget`, `LoadAction`, and `StoreAction`.
- `RenderTarget` is a texture view shape: texture plus mip level and array layer. It is not a `screen` enum.
- `Texture` is an opaque backend resource handle plus immutable `TextureDescriptor`.
- `Texture.id` is a package-visible `ResourceID`, so higher layers can hold textures but cannot see or mint backend handles.
- `Texture.init` and `ResourceID.init` are `package`, because platform backends live in the same Swift package while games/higher abstractions do not.
- Public resource creation should flow through `Device`, not direct initializers.
- `DeviceError` is the public error surface for device/resource creation failures. Keep texture-specific detail as cases inside `DeviceError` rather than creating separate texture errors for now.
- `PixlMetalPlatform` has begun as the first concrete platform target. `MetalDevice` owns a fixed-capacity `ResourcePool<MTLTexture>` whose capacity is supplied explicitly at initialization.
- `MetalDevice.makeTexture` maps `TextureDescriptor` to `MTLTextureDescriptor`, inserts the created `MTLTexture` into that pool, and returns package-minted `Texture`.
- `MetalDevice.makeQueue` creates a `MetalQueue` sharing the device's texture pool.
- `MetalQueue.submit` now executes ordered clear-only render passes: it resolves the target texture, maps mip/layer and load/store/clear state, ends the empty encoder, and commits the Metal command buffer.
- `PixlMetalPlatform.run()` is the single public macOS runtime entry point. It owns the temporary AppKit/MTKView window harness and its Metal device; `Pixl.run()` reaches it through Pixl's macOS-conditioned platform dependency.
- Metal implementation types and protocol witnesses remain internal. Keep the cross-platform public API in `PixlPlatform`; expose only the smallest deliberate platform construction boundary from `PixlMetalPlatform`.

Next likely smallest step:

- Connect the displayed MTKView's current drawable to the clear-only submission path, then design the smallest drawable/surface acquisition and presentation boundary. Avoid adding shaders, draw commands, bind groups, or pipelines before that works.

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

## Performance and Profiling

Performance is a first-class design constraint.

The `PixlPlatform` target enables provider-side aggressive cross-module optimization with `-enable-cmo-everything` in release builds. This serializes its package-private implementations so ordinary optimized consumers such as `PixlMetalPlatform` can specialize hot generic code such as `ResourcePool<Value>`. Do not combine it with `-cross-module-optimization`; that selects a less aggressive serialization mode and restores generic calls. Add the setting to another provider target only when that target gains hot cross-module implementation code.

Resource-pool checks and benchmarks have one platform-neutral source of truth in `PixlPlatformTestSupport`. The XCTest target is a native/Xcode adapter. Run `../.scripts/test` from this package, or `.scripts/test` from the repository root, for the release comparison: native first, then WASM/WASI through the Swift SDK and WasmKit. Pass `native` or `wasm` to run one side only.

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
