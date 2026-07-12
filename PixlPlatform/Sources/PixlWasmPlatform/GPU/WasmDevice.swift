import JavaScriptKit
import PixlPlatform

final class WasmDevice: Device {
    let webGPUDevice: JSObject
    let buffers: ResourcePool<JSObject>
    let pipelines: ResourcePool<WasmRenderPipeline>
    let textures: ResourcePool<JSObject>
    let immediateBuffer: JSObject
    let immediateBindGroup: JSObject
    let immediateAlignment: UInt32
    private let pipelineLayout: JSObject
    lazy var shaders = ShaderRegistry(device: self)

    init(device: JSObject, settings: RenderSettings) {
        webGPUDevice = device
        buffers = ResourcePool(capacity: settings.bufferCapacity)
        pipelines = ResourcePool(capacity: settings.pipelineCapacity)
        textures = ResourcePool(capacity: settings.textureCapacity)

        immediateAlignment = UInt32(device.limits.minUniformBufferOffsetAlignment.number ?? 256)
        let immediateCapacity = UInt64(settings.frameByteCapacity)
            + UInt64(settings.frameCommandCapacity) * UInt64(immediateAlignment - 1)
            + 4 * 1024
        let bufferDescriptor = object()
        bufferDescriptor["size"] = .number(Double(immediateCapacity))
        bufferDescriptor["usage"] = .number(Double(0x40 | 0x08))
        guard let immediateBuffer = device.createBuffer!(bufferDescriptor).object else {
            fatalError("WebGPU immediate buffer creation failed")
        }
        self.immediateBuffer = immediateBuffer

        let bufferLayout = object()
        bufferLayout["type"] = .string("uniform")
        bufferLayout["hasDynamicOffset"] = .boolean(true)
        let layoutEntry = object()
        layoutEntry["binding"] = .number(0)
        layoutEntry["visibility"] = .number(0x1)
        layoutEntry["buffer"] = .object(bufferLayout)
        let layoutEntries = array()
        _ = layoutEntries.jsObject.push!(layoutEntry)
        let bindGroupLayoutDescriptor = object()
        bindGroupLayoutDescriptor["entries"] = .object(layoutEntries.jsObject)
        guard let bindGroupLayout = device.createBindGroupLayout!(bindGroupLayoutDescriptor).object else {
            fatalError("WebGPU immediate bind-group layout creation failed")
        }

        let pipelineLayouts = array()
        _ = pipelineLayouts.jsObject.push!(bindGroupLayout)
        let pipelineLayoutDescriptor = object()
        pipelineLayoutDescriptor["bindGroupLayouts"] = .object(pipelineLayouts.jsObject)
        guard let pipelineLayout = device.createPipelineLayout!(pipelineLayoutDescriptor).object else {
            fatalError("WebGPU pipeline layout creation failed")
        }
        self.pipelineLayout = pipelineLayout

        let resource = object()
        resource["buffer"] = .object(immediateBuffer)
        resource["offset"] = .number(0)
        resource["size"] = .number(4 * 1024)
        let bindGroupEntry = object()
        bindGroupEntry["binding"] = .number(0)
        bindGroupEntry["resource"] = .object(resource)
        let bindGroupEntries = array()
        _ = bindGroupEntries.jsObject.push!(bindGroupEntry)
        let bindGroupDescriptor = object()
        bindGroupDescriptor["layout"] = .object(bindGroupLayout)
        bindGroupDescriptor["entries"] = .object(bindGroupEntries.jsObject)
        guard let immediateBindGroup = device.createBindGroup!(bindGroupDescriptor).object else {
            fatalError("WebGPU immediate bind group creation failed")
        }
        self.immediateBindGroup = immediateBindGroup
    }

    func makeBuffer(_ descriptor: BufferDescriptor) throws(DeviceError) -> Buffer {
        let native = object()
        native["size"] = .number(Double(descriptor.size))
        native["usage"] = .number(Double(bufferUsage(descriptor.usage)))
        guard let buffer = webGPUDevice.createBuffer!(native).object,
              let id = buffers.insert(buffer) else {
            throw .resourceCreationFailed(.buffer)
        }
        return Buffer(id: id, descriptor: descriptor)
    }

    func makeBuffer(copying bytes: UnsafeRawBufferPointer, usage: BufferUsage, memory: BufferMemory) throws(DeviceError) -> Buffer {
        let descriptor = BufferDescriptor(size: UInt64(bytes.count), usage: usage.union(.copyDestination), memory: memory)
        let buffer = try makeBuffer(descriptor)
        guard buffers.withValue(for: buffer.id, { native in
            let raw = bytes.bindMemory(to: UInt8.self)
            let source = JSUint8Array(buffer: raw)
            _ = webGPUDevice.queue.writeBuffer(native.pointee, 0, source.jsObject)
            return true
        }) == true else { throw .resourceCreationFailed(.buffer) }
        return buffer
    }

    func makeShaderLibrary(_ shader: borrowing Shader) throws(DeviceError) -> any ShaderLibrary {
        guard let code = shader.source(for: .wgsl) else { throw .resourceCreationFailed(.shader) }
        let descriptor = object(); descriptor["code"] = .string(code)
        guard let module = webGPUDevice.createShaderModule!(descriptor).object else { throw .resourceCreationFailed(.shader) }
        return WasmShaderLibrary(module: module)
    }

    func makeRenderPipeline(_ descriptor: RenderPipelineDescriptor) throws(DeviceError) -> RenderPipeline {
        guard let vertex = shaders.library(for: descriptor.vertex.shader) as? WasmShaderLibrary,
              let fragment = shaders.library(for: descriptor.fragment.shader) as? WasmShaderLibrary else {
            throw .invalidRenderPipelineDescriptor
        }
        let native = object(); native["layout"] = .object(pipelineLayout)
        let vertexStage = object(); vertexStage["module"] = .object(vertex.module); vertexStage["entryPoint"] = .string(descriptor.vertex.name)
        let buffersArray = array()
        var bufferIndex: UInt32 = 0
        while bufferIndex < descriptor.vertexLayout.bufferCount {
            let layout = descriptor.vertexLayout[buffer: bufferIndex]
            let buffer = object(); buffer["arrayStride"] = .number(Double(layout.stride)); buffer["stepMode"] = .string(layout.stepMode == .perVertex ? "vertex" : "instance")
            let attributes = array()
            var attributeIndex: UInt32 = 0
            while attributeIndex < descriptor.vertexLayout.attributeCount {
                let attribute = descriptor.vertexLayout[attribute: attributeIndex]
                if attribute.bufferIndex == layout.bufferIndex {
                    let item = object(); item["shaderLocation"] = .number(Double(attribute.location)); item["offset"] = .number(Double(attribute.offset)); item["format"] = .string(attribute.format.webGPUName)
                    _ = attributes.jsObject.push!(item)
                }
                attributeIndex += 1
            }
            buffer["attributes"] = .object(attributes.jsObject); _ = buffersArray.jsObject.push!(buffer); bufferIndex += 1
        }
        vertexStage["buffers"] = .object(buffersArray.jsObject); native["vertex"] = .object(vertexStage)
        let fragmentStage = object(); fragmentStage["module"] = .object(fragment.module); fragmentStage["entryPoint"] = .string(descriptor.fragment.name)
        let target = object(); target["format"] = .string(descriptor.colorFormat.webGPUName)
        let targets = array(); _ = targets.jsObject.push!(target); fragmentStage["targets"] = .object(targets.jsObject); native["fragment"] = .object(fragmentStage)
        guard let id = pipelines.insert(
            WasmRenderPipeline(device: webGPUDevice, descriptor: native)
        ) else { throw .renderPipelineCreationFailed }
        return RenderPipeline(id: id)
    }

    func makeTexture(_ descriptor: TextureDescriptor) throws(DeviceError) -> Texture { throw .resourceCreationFailed(.texture) }
    func makeQueue() throws(DeviceError) -> any Queue { makeWasmQueue() }

    func makeWasmQueue() -> WasmQueue {
        WasmQueue(
            device: webGPUDevice,
            buffers: buffers,
            pipelines: pipelines,
            textures: textures,
            immediateBuffer: immediateBuffer,
            immediateBindGroup: immediateBindGroup,
            immediateAlignment: immediateAlignment
        )
    }

    func destroy(_ buffer: Buffer) {
        precondition(buffers.remove(buffer.id), "Buffer is invalid or has already been destroyed")
    }

    func destroy(_ pipeline: RenderPipeline) {
        precondition(pipelines.remove(pipeline.id), "Render pipeline is invalid or has already been destroyed")
    }

    func destroy(_ texture: Texture) {
        precondition(textures.remove(texture.id), "Texture is invalid or has already been destroyed")
    }

    private func bufferUsage(_ usage: BufferUsage) -> UInt32 {
        var value: UInt32 = 0
        if usage.contains(.vertex) { value |= 0x20 }
        if usage.contains(.index) { value |= 0x10 }
        if usage.contains(.uniform) { value |= 0x40 }
        if usage.contains(.storage) { value |= 0x80 }
        if usage.contains(.copySource) { value |= 0x04 }
        if usage.contains(.copyDestination) { value |= 0x08 }
        return value
    }
}
