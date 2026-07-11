# PixlBackend Agent Notes

PixlBackend is a platform-agnostic Swift library for the lowest graphics/GPU layer of Pixl. It should define Swift-only types and protocols that can later be implemented by Metal, WebGPU, Vulkan, and DirectX 12 backends.

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
- `Texture.id` is `package`, so higher layers can hold textures but cannot see or mint backend resource IDs.
- `Texture.init` and `ResourceID.init` are `package`, because platform backends live in the same Swift package while games/higher abstractions do not.
- Public resource creation should flow through `Device`, not direct initializers.
- `DeviceError` is the public error surface for device/resource creation failures. Keep texture-specific detail as cases inside `DeviceError` rather than creating separate texture errors for now.
- `PixlMetalBackend` has begun as the first concrete backend target. `MetalDevice` owns a fixed-capacity `ResourcePool<MTLTexture>` whose capacity is supplied explicitly at initialization.
- `MetalDevice.makeTexture` maps `TextureDescriptor` to `MTLTextureDescriptor`, inserts the created `MTLTexture` into that pool, and returns package-minted `Texture`.

Current code note:

- `MetalDevice.makeTexture` uses typed throws: `throws(DeviceError)`.
- Check whether `Device.makeTexture` should also be updated to `throws(DeviceError)` if it has not already been changed when resuming.

Next likely smallest step:

- Execute a clear-only render pass in `PixlMetalBackend`: take a `Frame`, encode the first render pass against its `ColorAttachment`, apply load/store actions, and prove the target can be cleared. Avoid adding shaders, draw commands, bind groups, or pipelines before this works.

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
