# PixlBackend GPU Vocabulary

PixlBackend's lowest graphics layer is a modern, platform-agnostic GPU abstraction aligned closely with Metal, WebGPU, Vulkan, and DirectX 12 style APIs. It is not a legacy OpenGL/WebGL-style abstraction.

## Backend Mapping

Metal and WebGPU are the primary references. Vulkan and DirectX 12 are later targets used to keep naming honest.

| PixlBackend | Metal | WebGPU | Vulkan | DirectX 12 |
| --- | --- | --- | --- | --- |
| `Device` | `MTLDevice` | `GPUDevice` | `VkDevice` | `ID3D12Device` |
| `Queue` | `MTLCommandQueue` | `GPUQueue` | `VkQueue` | `ID3D12CommandQueue` |
| `CommandBuffer` | `MTLCommandBuffer` | `GPUCommandBuffer` / `GPUCommandEncoder` | `VkCommandBuffer` | `ID3D12GraphicsCommandList` |
| `Buffer` | `MTLBuffer` | `GPUBuffer` | `VkBuffer` | `ID3D12Resource` |
| `Texture` | `MTLTexture` | `GPUTexture` | `VkImage` / `VkImageView` | `ID3D12Resource` |
| `Sampler` | `MTLSamplerState` | `GPUSampler` | `VkSampler` | sampler descriptor / descriptor heap entry |
| `BufferUsage` | `MTLResourceOptions` plus encoder binding role | `GPUBufferUsage` | `VkBufferUsageFlags` | `D3D12_RESOURCE_FLAGS` / resource state |
| `TextureUsage` | `MTLTextureUsage` | `GPUTextureUsage` | `VkImageUsageFlags` | `D3D12_RESOURCE_FLAGS` / resource state |
| `ShaderLibrary` | `MTLLibrary` | shader module source/package | `VkShaderModule` | compiled DXIL blob |
| `ShaderFunction` | `MTLFunction` | shader entry point | shader stage entry point | shader entry point |
| `RenderPipeline` | `MTLRenderPipelineState` | `GPURenderPipeline` | `VkPipeline` | `ID3D12PipelineState` |
| `ComputePipeline` | `MTLComputePipelineState` | `GPUComputePipeline` | `VkPipeline` | `ID3D12PipelineState` |
| `VertexLayout` | `MTLVertexDescriptor` | `GPUVertexBufferLayout` | `VkVertexInput*` descriptions | `D3D12_INPUT_LAYOUT_DESC` |
| `BindGroupLayout` | emulated with argument layout / fixed slots | `GPUBindGroupLayout` | `VkDescriptorSetLayout` | root signature |
| `BindGroup` | emulated by setting buffers/textures/samplers | `GPUBindGroup` | `VkDescriptorSet` | descriptor table / root bindings |
| `Binding` | buffer/texture/sampler slot | bind group entry | descriptor binding | descriptor/root parameter |
| `RenderPass` | `MTLRenderCommandEncoder` plus pass descriptor | `GPURenderPassEncoder` | `VkRenderPass` / dynamic rendering | render pass encoded in command list |
| `ComputePass` | `MTLComputeCommandEncoder` | `GPUComputePassEncoder` | compute command buffer section | compute command list section |
| `RenderTarget` | `MTLTexture` / drawable texture | `GPUTextureView` / canvas texture | `VkImageView` / swapchain image | render target resource/view |
| `ColorAttachment` | `MTLRenderPassColorAttachmentDescriptor` | `GPURenderPassColorAttachment` | color attachment description | RTV |
| `DepthStencilAttachment` | `MTLRenderPassDepthAttachmentDescriptor` / stencil descriptor | `GPURenderPassDepthStencilAttachment` | depth/stencil attachment description | DSV |
| `DrawCommand` | `draw*` on `MTLRenderCommandEncoder` | `draw*` on `GPURenderPassEncoder` | `vkCmdDraw*` | `Draw*` on command list |
| `DispatchCommand` | `dispatchThreadgroups` / `dispatchThreads` | `dispatchWorkgroups` | `vkCmdDispatch` | `Dispatch` |
| `CopyCommand` | blit encoder copy commands | command encoder copy commands | `vkCmdCopy*` | `Copy*` commands |

## Core Objects

`Device`
: Logical access to the GPU. Creates resources such as buffers, textures, samplers, pipelines, and command queues.

`Queue`
: Submission lane for encoded GPU work. Owns the act of submitting command buffers for execution.

`CommandBuffer`
: A recorded unit of GPU work submitted to a queue. Contains render passes, compute passes, copies, or other encoded commands.

## Resources

`Buffer`
: Raw GPU-visible memory. Used for vertices, indices, uniforms, storage data, staging, or copies depending on usage flags.

`Texture`
: GPU image resource. Used for sampled images, render targets, depth buffers, storage textures, and intermediate frame data.

`Sampler`
: Rules for reading texture data, such as filtering, address modes, mip behavior, and comparison behavior.

`BufferUsage`
: Declares intended buffer roles, such as vertex, index, uniform, storage, copy source, and copy destination.

`TextureUsage`
: Declares intended texture roles, such as sampled, render attachment, storage, copy source, and copy destination.

## Shaders and Pipelines

`ShaderLibrary`
: Collection of compiled shader functions available to the backend.

`ShaderFunction`
: A specific shader entry point, such as a vertex, fragment, or compute function.

`RenderPipeline`
: Compiled render configuration. Combines shader functions, vertex layout, attachment formats, blending, depth/stencil behavior, and primitive topology.

`ComputePipeline`
: Compiled compute configuration. Combines a compute shader function with the binding layout needed for dispatch.

`VertexLayout`
: Describes how vertex buffer bytes map to shader attributes, such as position, UV, color, normal, or tangent.

## Bindings

`BindGroupLayout`
: Declares the resource slots a pipeline expects, including buffers, textures, samplers, and their access modes.

`BindGroup`
: Concrete set of resources bound together for a draw or dispatch. Similar to WebGPU bind groups or Vulkan descriptor sets.

`Binding`
: One resource assignment inside a bind group, such as a uniform buffer, storage buffer, sampled texture, storage texture, or sampler.

`ResourceAccess`
: Declares whether a bound resource is read-only, write-only, or read-write.

## Passes and Targets

`RenderPass`
: A sequence of draw work targeting one or more attachments. Defines color/depth targets, clear/load/store behavior, and draw commands.

`ComputePass`
: A sequence of compute dispatch work. Used for GPU-side simulation, particles, culling, generation, and other parallel workloads.

`RenderTarget`
: A texture or drawable that render passes can draw into. May later be sampled by another pass for compositing or post-processing.

`ColorAttachment`
: Render pass color output, usually a screen drawable or texture.

`DepthStencilAttachment`
: Optional render pass depth/stencil output for depth testing, stencil operations, and later 3D support.

## Commands

`DrawCommand`
: Render command that binds a render pipeline, resources, vertex/index buffers, and issues a draw.

`DispatchCommand`
: Compute command that binds a compute pipeline, resources, and dispatches threadgroups.

`CopyCommand`
: Transfer command for moving data between buffers, textures, and CPU-visible staging resources.

## Frame Shape

`Frame`
: Platform-agnostic description of GPU work for one frame. Contains ordered passes and enough metadata for profiling.

Frame pass
: Either a render pass, compute pass, or copy pass. Ordering is significant because later passes may consume resources produced by earlier passes.

## Profiling Terms

`FrameMetrics`
: CPU-side timing and counters for a frame.

`PassMetrics`
: CPU-side timing and counters for one pass, including draw count, dispatch count, vertices, indices, uploaded bytes, and resource bind counts.

`RenderTotals`
: Aggregated frame counters such as batches, culled objects, submitted vertices, uploaded bytes, and pipeline changes.
