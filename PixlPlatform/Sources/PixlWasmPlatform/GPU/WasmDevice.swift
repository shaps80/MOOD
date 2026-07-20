import JavaScriptKit
import PixlPlatform

final class WasmDevice: Device {
    let webGPUDevice: JSObject
    let buffers: ResourcePool<JSObject>
    let pipelines: ResourcePool<WasmRenderPipeline>
    let samplers: ResourcePool<JSObject>
    let textures: ResourcePool<JSObject>
    let immediateBuffer: JSObject
    let immediateAlignment: UInt32
    let bindGroupLayout: JSObject
    let defaultTexture: JSObject
    let defaultSampler: JSObject
    private let pipelineLayout: JSObject
    private let shaderModule: JSObject

    init(device: JSObject, settings: RenderSettings) {
        webGPUDevice = device
        buffers = ResourcePool(capacity: settings.bufferCapacity)
        pipelines = ResourcePool(capacity: settings.pipelineCapacity)
        samplers = ResourcePool(capacity: settings.samplerCapacity)
        textures = ResourcePool(capacity: settings.textureCapacity)

        immediateAlignment = UInt32(device.limits.minUniformBufferOffsetAlignment.number ?? 256)
        let immediateCapacity = UInt64(settings.frameByteCapacity)
            + UInt64(settings.frameCommandCapacity) * UInt64(immediateAlignment - 1)
            + 4 * 1024
        let bufferDescriptor = object()
        bufferDescriptor["size"] = .number(Double(immediateCapacity))
        bufferDescriptor["usage"] = .number(Double(0x40 | 0x20 | 0x08))
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
        let textureLayout = object()
        textureLayout["sampleType"] = .string("float")
        textureLayout["viewDimension"] = .string("2d")
        textureLayout["multisampled"] = .boolean(false)
        let textureLayoutEntry = object()
        textureLayoutEntry["binding"] = .number(1)
        textureLayoutEntry["visibility"] = .number(0x2)
        textureLayoutEntry["texture"] = .object(textureLayout)

        let samplerLayout = object()
        samplerLayout["type"] = .string("filtering")
        let samplerLayoutEntry = object()
        samplerLayoutEntry["binding"] = .number(2)
        samplerLayoutEntry["visibility"] = .number(0x2)
        samplerLayoutEntry["sampler"] = .object(samplerLayout)

        let layoutEntries = array()
        _ = layoutEntries.jsObject.push!(layoutEntry)
        _ = layoutEntries.jsObject.push!(textureLayoutEntry)
        _ = layoutEntries.jsObject.push!(samplerLayoutEntry)
        let bindGroupLayoutDescriptor = object()
        bindGroupLayoutDescriptor["entries"] = .object(layoutEntries.jsObject)
        guard let bindGroupLayout = device.createBindGroupLayout!(bindGroupLayoutDescriptor).object else {
            fatalError("WebGPU immediate bind-group layout creation failed")
        }
        self.bindGroupLayout = bindGroupLayout

        let pipelineLayouts = array()
        _ = pipelineLayouts.jsObject.push!(bindGroupLayout)
        let pipelineLayoutDescriptor = object()
        pipelineLayoutDescriptor["bindGroupLayouts"] = .object(pipelineLayouts.jsObject)
        guard let pipelineLayout = device.createPipelineLayout!(pipelineLayoutDescriptor).object else {
            fatalError("WebGPU pipeline layout creation failed")
        }
        self.pipelineLayout = pipelineLayout

        let defaultTextureDescriptor = object()
        let defaultTextureSize = object()
        defaultTextureSize["width"] = .number(1)
        defaultTextureSize["height"] = .number(1)
        defaultTextureSize["depthOrArrayLayers"] = .number(1)
        defaultTextureDescriptor["size"] = .object(defaultTextureSize)
        defaultTextureDescriptor["dimension"] = .string("2d")
        defaultTextureDescriptor["format"] = .string("rgba8unorm")
        defaultTextureDescriptor["usage"] = .number(Double(0x04 | 0x02))
        guard let defaultTexture = device.createTexture!(
            defaultTextureDescriptor
        ).object else {
            fatalError("Pixl WebGPU default texture creation failed")
        }
        self.defaultTexture = defaultTexture

        let white: [UInt8] = [255, 255, 255, 255]
        white.withUnsafeBytes { bytes in
            let source = JSUint8Array(
                buffer: bytes.bindMemory(to: UInt8.self)
            )
            let destination = object()
            destination["texture"] = .object(defaultTexture)
            let layout = object()
            let size = object()
            size["width"] = .number(1)
            size["height"] = .number(1)
            size["depthOrArrayLayers"] = .number(1)
            _ = device.queue.writeTexture(
                destination,
                source.jsObject,
                layout,
                size
            )
        }

        let defaultSamplerDescriptor = object()
        defaultSamplerDescriptor["minFilter"] = .string("nearest")
        defaultSamplerDescriptor["magFilter"] = .string("nearest")
        defaultSamplerDescriptor["mipmapFilter"] = .string("nearest")
        guard let defaultSampler = device.createSampler!(
            defaultSamplerDescriptor
        ).object else {
            fatalError("Pixl WebGPU default sampler creation failed")
        }
        self.defaultSampler = defaultSampler

        guard let shaderBytes = WasmBuiltinAssets.read("__pixl/Shaders.wgsl") else {
            fatalError("Pixl WebGPU shader source could not be loaded")
        }
        let shaderDescriptor = object()
        shaderDescriptor["code"] = .string(
            String(decoding: shaderBytes, as: UTF8.self)
        )
        guard let shaderModule = device.createShaderModule!(shaderDescriptor).object else {
            fatalError("Pixl WebGPU shader module creation failed")
        }
        self.shaderModule = shaderModule
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

    func makeRenderPipeline(_ descriptor: RenderPipelineDescriptor) throws(DeviceError) -> RenderPipeline {
        let native = object(); native["layout"] = .object(pipelineLayout)
        let vertexStage = object(); vertexStage["module"] = .object(shaderModule); vertexStage["entryPoint"] = .string(descriptor.vertex.name)
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
        let fragmentStage = object(); fragmentStage["module"] = .object(shaderModule); fragmentStage["entryPoint"] = .string(descriptor.fragment.name)
        let target = object(); target["format"] = .string(descriptor.colorFormat.webGPUName)
        if descriptor.blendMode != .replace {
            let color = object(); color["operation"] = .string("add"); color["srcFactor"] = .string(descriptor.blendMode == .premultiplied ? "one" : "src-alpha"); color["dstFactor"] = .string("one-minus-src-alpha")
            let alpha = object(); alpha["operation"] = .string("add"); alpha["srcFactor"] = .string("one"); alpha["dstFactor"] = .string("one-minus-src-alpha")
            let blend = object(); blend["color"] = .object(color); blend["alpha"] = .object(alpha)
            target["blend"] = .object(blend)
        }
        let targets = array(); _ = targets.jsObject.push!(target); fragmentStage["targets"] = .object(targets.jsObject); native["fragment"] = .object(fragmentStage)
        guard let id = pipelines.insert(
            WasmRenderPipeline(device: webGPUDevice, descriptor: native)
        ) else { throw .renderPipelineCreationFailed }
        return RenderPipeline(id: id)
    }

    func makeTexture(
        _ descriptor: TextureDescriptor
    ) throws(DeviceError) -> Texture {
        guard descriptor.size.width > 0,
              descriptor.size.height > 0,
              descriptor.size.depthOrArrayLayers > 0,
              descriptor.sampleCount > 0
        else {
            throw .invalidTextureDescriptor(descriptor)
        }

        let size = object()
        size["width"] = .number(Double(descriptor.size.width))
        size["height"] = .number(Double(descriptor.size.height))
        size["depthOrArrayLayers"] = .number(
            Double(descriptor.size.depthOrArrayLayers)
        )
        let native = object()
        native["size"] = .object(size)
        native["dimension"] = .string("2d")
        native["format"] = .string(descriptor.format.webGPUName)
        native["sampleCount"] = .number(Double(descriptor.sampleCount))
        native["usage"] = .number(Double(textureUsage(descriptor.usage)))
        guard let texture = webGPUDevice.createTexture!(native).object,
              let id = textures.insert(texture)
        else {
            throw .resourceCreationFailed(.texture)
        }
        return Texture(id: id, descriptor: descriptor)
    }

    func makeTexture(
        copying bytes: [UInt8],
        descriptor: TextureDescriptor,
        bytesPerRow: UInt32
    ) throws(DeviceError) -> Texture {
        guard descriptor.sampleCount == 1,
              descriptor.size.depthOrArrayLayers == 1,
              descriptor.usage.contains(.copyDestination),
              bytesPerRow >= UInt32(descriptor.size.width * 4),
              bytes.count >= Int(bytesPerRow) * descriptor.size.height
        else {
            throw .invalidTextureDescriptor(descriptor)
        }

        let texture = try makeTexture(descriptor)
        guard textures.withValue(for: texture.id, { native in
            bytes.withUnsafeBytes { bytes in
                let source = JSUint8Array(
                    buffer: bytes.bindMemory(to: UInt8.self)
                )
                let destination = object()
                destination["texture"] = .object(native.pointee)
                let layout = object()
                layout["bytesPerRow"] = .number(Double(bytesPerRow))
                layout["rowsPerImage"] = .number(
                    Double(descriptor.size.height)
                )
                let size = object()
                size["width"] = .number(Double(descriptor.size.width))
                size["height"] = .number(Double(descriptor.size.height))
                size["depthOrArrayLayers"] = .number(1)
                _ = webGPUDevice.queue.writeTexture(
                    destination,
                    source.jsObject,
                    layout,
                    size
                )
            }
            return ()
        }) != nil else {
            throw .resourceCreationFailed(.texture)
        }
        return texture
    }

    func makeSampler(
        _ descriptor: SamplerDescriptor
    ) throws(DeviceError) -> Sampler {
        let native = object()
        native["minFilter"] = .string(descriptor.minFilter.webGPUName)
        native["magFilter"] = .string(descriptor.magFilter.webGPUName)
        native["mipmapFilter"] = .string(
            descriptor.mipFilter.webGPUName
        )
        native["addressModeU"] = .string(
            descriptor.addressModeU.webGPUName
        )
        native["addressModeV"] = .string(
            descriptor.addressModeV.webGPUName
        )
        native["addressModeW"] = .string(
            descriptor.addressModeW.webGPUName
        )
        guard let sampler = webGPUDevice.createSampler!(native).object,
              let id = samplers.insert(sampler)
        else {
            throw .resourceCreationFailed(.sampler)
        }
        return Sampler(id: id, descriptor: descriptor)
    }
    func makeQueue() throws(DeviceError) -> any Queue { makeWasmQueue() }

    func makeWasmQueue() -> WasmQueue {
        WasmQueue(
            device: webGPUDevice,
            buffers: buffers,
            pipelines: pipelines,
            samplers: samplers,
            textures: textures,
            immediateBuffer: immediateBuffer,
            immediateAlignment: immediateAlignment,
            bindGroupLayout: bindGroupLayout,
            defaultTexture: defaultTexture,
            defaultSampler: defaultSampler
        )
    }

    func destroy(_ buffer: Buffer) {
        guard buffers.withValue(for: buffer.id, { native in
            _ = native.pointee.destroy!()
        }) != nil else {
            preconditionFailure(
                "Buffer is invalid or has already been destroyed"
            )
        }
        let removed = buffers.remove(buffer.id)
        precondition(
            removed,
            "Buffer is invalid or has already been destroyed"
        )
    }

    func destroy(_ pipeline: RenderPipeline) {
        let removed = pipelines.remove(pipeline.id)
        precondition(
            removed,
            "Render pipeline is invalid or has already been destroyed"
        )
    }

    func destroy(_ sampler: Sampler) {
        let removed = samplers.remove(sampler.id)
        precondition(
            removed,
            "Sampler is invalid or has already been destroyed"
        )
    }

    func destroy(_ texture: Texture) {
        guard textures.withValue(for: texture.id, { native in
            _ = native.pointee.destroy!()
        }) != nil else {
            preconditionFailure(
                "Texture is invalid or has already been destroyed"
            )
        }
        let removed = textures.remove(texture.id)
        precondition(
            removed,
            "Texture is invalid or has already been destroyed"
        )
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

    private func textureUsage(_ usage: TextureUsage) -> UInt32 {
        var value: UInt32 = 0
        if usage.contains(.copySource) { value |= 0x01 }
        if usage.contains(.copyDestination) { value |= 0x02 }
        if usage.contains(.sampled) { value |= 0x04 }
        if usage.contains(.storage) { value |= 0x08 }
        if usage.contains(.renderAttachment) { value |= 0x10 }
        return value
    }
}
