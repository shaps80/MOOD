# PixlPlatform GPU Vocabulary

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
| `RenderPipeline` | `MTLRenderPipelineState` | `ID3D12PipelineState` | `GPURenderPipeline` variant | `VkPipeline` variant |
| `VertexLayout` | `MTLVertexDescriptor` | `D3D12_INPUT_LAYOUT_DESC` | `GPUVertexBufferLayout` | `VkVertexInput*` descriptions |
| `RenderPassDescriptor` | `MTLRenderPassDescriptor` | RTV/DSV pass configuration | `GPURenderPassDescriptor` | dynamic-rendering/pass configuration |
| `RenderPassEncoder` | `MTLRenderCommandEncoder` | graphics command list methods | `GPURenderPassEncoder` | `vkCmd*` recording |
| `setRenderPipeline` | `setRenderPipelineState` | `SetPipelineState` | `setPipeline` | `vkCmdBindPipeline` |
| `setVertexBuffer` | `setVertexBuffer` | root/descriptor or vertex-buffer binding | vertex buffer or internal bind group | vertex buffer or internal descriptor set |
| `drawPrimitives` | `drawPrimitives` | `DrawInstanced` | `draw` | `vkCmdDraw` |
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

## Resource Ownership

`ResourceID`
: Package-visible 64-bit generational handle: 32-bit direct slot index plus 32-bit generation. Generation zero is reserved. Stale handles fail lookup after destruction/reuse. A phantom generic tag was measured and rejected after roughly 55% release lookup regression across the package seam.

`ResourcePool`
: Package-level fixed-capacity native-resource storage. It uses contiguous manually managed slots, O(1) lookup/removal, generation validation, and an intrusive free list. It allocates only at initialization and contains no internal synchronization.

`Buffer`, `Texture`, `RenderPipeline`
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

`RenderTarget`
: Texture view shape selecting a texture, mip level, and array layer.

## Shaders and Pipelines

`Shader`
: Owned generated backend artifacts. Current generated values carry compiled Metal-library bytes and WGSL source. Artifact-format knowledge is temporarily accepted here but should eventually move behind generated/backend-specific access.

`ShaderRegistry`
: Platform-owned native-library retention. Built-in shaders are registered before game initialization; games append generated shaders without retaining native shader-library objects.

`ShaderFunction`
: Logical shader entry point carrying its originating `Shader` plus function name.

`RenderPipelineDescriptor`
: Startup description of shader functions, vertex input layout, and attachment format. Exact primitive topology is not pipeline state in Pixl's Metal-first interface; it is supplied to `drawPrimitives`. Backends that require topology at pipeline creation own/cache the corresponding native variants.

`VertexLayout`
: Fixed-capacity startup description of vertex-buffer streams and shader attributes. It describes GPU byte layout only; games own their Swift vertex types and bytes.

## Render Recording

`RenderPassDescriptor`
: Attachment/load/store description used to begin one render pass. It contains no frame-storage bookkeeping.

`RenderPassEncoder`
: Metal-shaped public recorder. Callers set pipeline/resource state and then issue draws. Current commands are `setRenderPipeline`, `setVertexBuffer`, and `drawPrimitives`.

`RenderCommand`
: Package-only compact command representation stored by `Frame`. It is not public game vocabulary. Resource commands store `ResourceID` rather than copying full descriptors into every recorded command.

`PrimitiveTopology`
: Exact primitive interpretation supplied to `drawPrimitives`: point, line, line strip, triangle, or triangle strip.

Commands for a pass must be recorded contiguously. `Frame` preallocates command storage from startup-only `RenderSettings.frameCommandCapacity`; recording performs no allocation or dynamic dispatch.

## Dynamic Data and Resource Slots

Pixl's public direction is stage/resource-specific encoder intent, matching Metal: vertex/fragment buffers, bytes, textures, and samplers; compute encoders imply the compute stage. Public bind groups and dynamic-offset flags are not current Pixl concepts.

Dynamic CPU-to-GPU transfer storage, upload rings, WebGPU bind groups, Vulkan descriptor sets, and DX12 descriptor allocation are private adapter mechanisms. Before adding calls such as `setVertexBytes`, define fixed-capacity recording storage, GPU-completion retirement, and readback lifetime. Do not expose a generic per-call write API that allocates staging resources or synchronizes CPU/GPU execution.

## Required Future Depth

Compute is required and must use the same encoder-command direction: compute pipeline state, buffer/texture resource slots, access modes, and dispatch commands. Compute output must feed later render passes in the same frame.

Other explicit gates include indexed draws, samplers, texture binding, multiple color attachments, depth/stencil, blending, multisampling, richer texture dimensions/mips, copy commands, dynamic bytes, readback, and profiling counters. Add each through playable Game needs without widening existing modules into shallow configuration bags.
