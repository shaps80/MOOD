import JavaScriptKit
import PixlPlatform

final class WasmDevice: Device {
    let webGPUDevice: JSObject
    let buffers: ResourcePool<JSObject>
    let pipelines: ResourcePool<JSObject>
    let textures: ResourcePool<JSObject>
    lazy var shaders = ShaderRegistry(device: self)

    init(device: JSObject, settings: RenderSettings) {
        webGPUDevice = device
        buffers = ResourcePool(capacity: settings.bufferCapacity)
        pipelines = ResourcePool(capacity: settings.pipelineCapacity)
        textures = ResourcePool(capacity: settings.textureCapacity)
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
        let native = object(); native["layout"] = .string("auto")
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
        let primitive = object(); primitive["topology"] = .string(descriptor.topology.webGPUName); native["primitive"] = .object(primitive)
        guard let pipeline = webGPUDevice.createRenderPipeline!(native).object,
              let id = pipelines.insert(pipeline) else { throw .renderPipelineCreationFailed }
        return RenderPipeline(id: id)
    }

    func makeTexture(_ descriptor: TextureDescriptor) throws(DeviceError) -> Texture { throw .resourceCreationFailed(.texture) }
    func makeQueue() throws(DeviceError) -> any Queue { WasmQueue(device: webGPUDevice, buffers: buffers, pipelines: pipelines, textures: textures) }

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
