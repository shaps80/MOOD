import Pixl
import JavaScriptKit
import Swift

final class Renderer {
    var canvas: JSObject?
    var lastCanvasDisplaySize: CanvasDisplaySize?

    var device: JSObject?
    private var context: JSObject?
    var canvasFormat = "bgra8unorm"
    var pipelineStates: [BlendMode: JSObject] = [:]
    var sampledPipeline: JSObject?
    var presentPipeline: JSObject?
    private var quadBuffer: JSObject?
    private var instanceBuffer: JSObject?
    private var instanceBufferCapacity = 0
    private var nearestSampler: JSObject?
    private var linearSampler: JSObject?
    private var whiteTexture: JSObject?
    private var sceneTexture: JSObject?
    private var alternateSceneTexture: JSObject?
    private var sceneTextureSize: Vec2 = .zero
    private var itemData: [Float] = []
    private var preparedBatches: [PreparedBatch] = []
    private var renderPlanner = RenderPlanner()

    var spriteTextures: [TextureID: JSObject] = [:]
    var spriteTextureSizes: [TextureID: Vec2] = [:]
    var spriteImages: [TextureID: JSObject] = [:]
    var spriteLoadClosures: [TextureID: JSClosure] = [:]
    var spriteErrorClosures: [TextureID: JSClosure] = [:]
    let interpolationMode: InterpolationMode

    private var adapterClosure: JSClosure?
    private var deviceClosure: JSClosure?
    private var failureClosure: JSClosure?
    private var uncapturedErrorClosure: JSClosure?

    init(interpolationMode: InterpolationMode) {
        self.interpolationMode = interpolationMode
    }

    func configure(completion: @escaping () -> Void) {
        configureCanvas()

        guard let gpu = JSObject.global.navigator.gpu.object else {
            fatalError("WebGPU is not available")
        }

        failureClosure = JSClosure { arguments in
            let reason = arguments.first?.description ?? "unknown error"
            fatalError("Unable to configure WebGPU: \(reason)")
        }
        deviceClosure = JSClosure { [weak self] arguments in
            guard let self, let device = arguments.first?.object else {
                fatalError("Unable to acquire WebGPU device")
            }
            self.finishConfiguration(gpu: gpu, device: device)
            completion()
            return .undefined
        }
        adapterClosure = JSClosure { [weak self] arguments in
            guard let self, let adapter = arguments.first?.object else {
                fatalError("Unable to acquire WebGPU adapter")
            }
            let promise = adapter.requestDevice!()
            _ = promise.then(self.deviceClosure).catch(self.failureClosure)
            return .undefined
        }

        let promise = gpu.requestAdapter!()
        _ = promise.then(adapterClosure).catch(failureClosure)
    }

    private func finishConfiguration(gpu: JSObject, device: JSObject) {
        guard let canvas, let context = canvas.getContext!("webgpu").object else {
            fatalError("Unable to create WebGPU canvas context")
        }

        self.device = device
        self.context = context
        uncapturedErrorClosure = JSClosure { arguments in
            let message = arguments.first?.error.message.string ?? "unknown WebGPU validation error"
            _ = JSObject.global.console.error("WebGPU validation error: \(message)")
            return .undefined
        }
        _ = device.addEventListener!("uncapturederror", uncapturedErrorClosure)
        canvasFormat = gpu.getPreferredCanvasFormat!().string ?? "bgra8unorm"
        configureCanvasContext()
        quadBuffer = makeBuffer(
            label: "Pixl quad vertices",
            size: quadVertices.count * MemoryLayout<Float>.stride,
            usage: gpuBufferUsageVertex | gpuBufferUsageCopyDst
        )
        if let quadBuffer {
            _ = device.queue.writeBuffer(quadBuffer, 0, JSFloat32Array(quadVertices))
        }
        nearestSampler = makeSampler(filter: "nearest")
        linearSampler = makeSampler(filter: "linear")
        whiteTexture = makeWhiteTexture()
        makePipelines()
    }

    func draw(game: Game) {
        guard let device, let context else { return }
        syncCanvasWithGameResolution(game: game)
        configureSceneTargets(game: game)
        guard var currentSceneTexture = sceneTexture,
              var nextSceneTexture = alternateSceneTexture,
              let instanceBuffer = uploadItemInstances(frame: renderPlanner.prepareFrame(
                game: game,
                textureSizes: spriteTextureSizes
              ))
        else { return }

        let commandEncoder = device.createCommandEncoder!(object("label", "Pixl frame")).object!
        var scenePass = beginScenePass(
            commandEncoder: commandEncoder,
            texture: currentSceneTexture,
            game: game,
            load: false
        )

        for batch in preparedBatches {
            if batch.blendMode.usesSceneSampling {
                _ = scenePass.end!()
                copyScene(from: currentSceneTexture, to: nextSceneTexture, commandEncoder: commandEncoder, game: game)
                scenePass = beginScenePass(
                    commandEncoder: commandEncoder,
                    texture: nextSceneTexture,
                    game: game,
                    load: true
                )
                draw(batch, sampledTexture: currentSceneTexture, instanceBuffer: instanceBuffer, pass: scenePass)
                swap(&currentSceneTexture, &nextSceneTexture)
            } else {
                draw(batch, sampledTexture: nil, instanceBuffer: instanceBuffer, pass: scenePass)
            }
        }
        _ = scenePass.end!()

        let canvasTexture = context.getCurrentTexture!().object!
        let presentPass = beginPass(
            commandEncoder: commandEncoder,
            texture: canvasTexture,
            clearColor: .black,
            load: false
        )
        if let presentPipeline, let quadBuffer {
            _ = presentPass.setPipeline!(presentPipeline)
            _ = presentPass.setVertexBuffer!(0, quadBuffer)
            _ = presentPass.setBindGroup!(0, presentBindGroup(texture: currentSceneTexture))
            _ = presentPass.draw!(6, 1, 0, 0)
        }
        _ = presentPass.end!()
        _ = device.queue.submit(array(commandEncoder.finish!()))
    }

    private func uploadItemInstances(frame: RenderFrame) -> JSObject? {
        prepareBatches(frame: frame)
        guard !itemData.isEmpty, let device else { return nil }
        let byteCount = itemData.count * MemoryLayout<Float>.stride
        if instanceBufferCapacity < byteCount {
            instanceBuffer = makeBuffer(
                label: "Pixl item instances",
                size: byteCount,
                usage: gpuBufferUsageVertex | gpuBufferUsageCopyDst
            )
            instanceBufferCapacity = byteCount
        }
        guard let instanceBuffer else { return nil }
        _ = device.queue.writeBuffer(instanceBuffer, 0, JSFloat32Array(itemData))
        return instanceBuffer
    }

    private func prepareBatches(frame: RenderFrame) {
        itemData.removeAll(keepingCapacity: true)
        preparedBatches.removeAll(keepingCapacity: true)
        preparedBatches.reserveCapacity(frame.batches.count)
        for batch in frame.batches {
            switch batch {
            case .items(let textureID, let blendMode, let items):
                let material = textureID.flatMap { spriteTextures[$0] }.map(RenderMaterial.texture) ?? .color
                let startIndex = itemData.count / itemStride
                for item in items {
                    appendItem(item, useFallbackTextureRect: textureID != nil && material.isColor)
                }
                let count = (itemData.count / itemStride) - startIndex
                if count > 0 {
                    preparedBatches.append(.items(material: material, blendMode: blendMode, startIndex: startIndex, instanceCount: count))
                }
            }
        }
    }

    private func appendItem(_ item: RenderItem, useFallbackTextureRect: Bool) {
        let textureRect = useFallbackTextureRect ? TextureRect.full : item.textureRect
        let rotation = sincos(item.transform.rotation)
        itemData.append(contentsOf: [
            Float(item.transform.center.x), Float(item.transform.center.y), Float(item.transform.size.x), Float(item.transform.size.y),
            Float(rotation.cos), Float(rotation.sin), 0, 0,
            Float(textureRect.origin.x), Float(textureRect.origin.y), Float(textureRect.size.x), Float(textureRect.size.y),
            Float(item.color.red), Float(item.color.green), Float(item.color.blue), Float(item.color.alpha),
            Float(item.info.x), Float(item.info.y), Float(item.info.z), Float(item.info.w),
            Float(item.line.x), Float(item.line.y), Float(item.line.z), Float(item.line.w),
            Float(item.fillColor.red), Float(item.fillColor.green), Float(item.fillColor.blue), Float(item.fillColor.alpha),
            Float(item.strokeColor.red), Float(item.strokeColor.green), Float(item.strokeColor.blue), Float(item.strokeColor.alpha),
            Float(item.flags.x), Float(item.flags.y), Float(item.flags.z), Float(item.flags.w)
        ])
    }

    private func draw(_ batch: PreparedBatch, sampledTexture: JSObject?, instanceBuffer: JSObject, pass: JSObject) {
        guard let device, let whiteTexture else { return }
        let pipeline = sampledTexture == nil ? pipelineStates[batch.blendMode] : sampledPipeline
        guard let pipeline else { return }
        let materialTexture = batch.material.texture ?? whiteTexture
        let uniforms: [Float] = [
            Float(sceneTextureSize.x), Float(sceneTextureSize.y), 1, 0,
            batch.material.useTexture ? 1 : 0,
            sampledTexture == nil ? 0 : 1,
            Float(batch.blendMode.shaderValue), 0
        ]
        guard let batchUniformBuffer = makeBuffer(
            label: "Pixl batch uniforms",
            size: uniformBufferSize,
            usage: gpuBufferUsageUniform | gpuBufferUsageCopyDst
        ) else { return }
        _ = device.queue.writeBuffer(batchUniformBuffer, 0, JSFloat32Array(uniforms))
        let bindGroup = itemBindGroup(
            pipeline: pipeline,
            uniformBuffer: batchUniformBuffer,
            texture: materialTexture,
            sampledTexture: sampledTexture ?? whiteTexture
        )
        _ = pass.setPipeline!(pipeline)
        _ = pass.setVertexBuffer!(0, quadBuffer)
        _ = pass.setVertexBuffer!(1, instanceBuffer, batch.startIndex * itemStrideBytes)
        _ = pass.setBindGroup!(0, bindGroup)
        _ = pass.draw!(6, batch.instanceCount, 0, 0)
    }

    private func configureSceneTargets(game: Game) {
        let size = Vec2(x: max(1, game.logicalResolution.x.rounded()), y: max(1, game.logicalResolution.y.rounded()))
        guard size != sceneTextureSize else { return }
        sceneTexture = makeSceneTexture(size: size, label: "Pixl scene")
        alternateSceneTexture = makeSceneTexture(size: size, label: "Pixl alternate scene")
        sceneTextureSize = size
    }

    private func beginScenePass(commandEncoder: JSObject, texture: JSObject, game: Game, load: Bool) -> JSObject {
        beginPass(commandEncoder: commandEncoder, texture: texture, clearColor: game.clearColor, load: load)
    }

    private func beginPass(commandEncoder: JSObject, texture: JSObject, clearColor: Color, load: Bool) -> JSObject {
        let attachment = object()
        attachment.view = texture.createView!()
        attachment.loadOp = .string(load ? "load" : "clear")
        attachment.storeOp = .string("store")
        attachment.clearValue = .object(object(
            "r", clearColor.red, "g", clearColor.green,
            "b", clearColor.blue, "a", clearColor.alpha
        ))
        let descriptor = object("colorAttachments", array(attachment))
        return commandEncoder.beginRenderPass!(descriptor).object!
    }

    private func copyScene(from source: JSObject, to destination: JSObject, commandEncoder: JSObject, game: Game) {
        let extent = object("width", game.logicalResolution.x.rounded(), "height", game.logicalResolution.y.rounded(), "depthOrArrayLayers", 1)
        _ = commandEncoder.copyTextureToTexture!(object("texture", source), object("texture", destination), extent)
    }

    private func makeSceneTexture(size: Vec2, label: String) -> JSObject? {
        guard let device else { return nil }
        let descriptor = object(
            "label", label, "size", object("width", size.x, "height", size.y, "depthOrArrayLayers", 1),
            "format", "rgba8unorm", "usage", gpuTextureUsageRenderAttachment | gpuTextureUsageTextureBinding | gpuTextureUsageCopySrc | gpuTextureUsageCopyDst
        )
        return device.createTexture!(descriptor).object
    }

    private func makeBuffer(label: String, size: Int, usage: Int) -> JSObject? {
        device?.createBuffer!(object("label", label, "size", max(4, size), "usage", usage)).object
    }

    private func makeSampler(filter: String) -> JSObject? {
        device?.createSampler!(object("magFilter", filter, "minFilter", filter, "addressModeU", "clamp-to-edge", "addressModeV", "clamp-to-edge")).object
    }

    private func makeWhiteTexture() -> JSObject? {
        guard let device else { return nil }
        let texture = device.createTexture!(object(
            "label", "Pixl white texture", "size", array(1, 1), "format", "rgba8unorm",
            "usage", gpuTextureUsageTextureBinding | gpuTextureUsageCopyDst
        )).object!
        _ = device.queue.writeTexture(
            object("texture", texture), JSUint8Array([255, 255, 255, 255]),
            object(), object("width", 1, "height", 1, "depthOrArrayLayers", 1)
        )
        return texture
    }

    private func itemBindGroup(pipeline: JSObject, uniformBuffer: JSObject, texture: JSObject, sampledTexture: JSObject) -> JSObject {
        let entries = array(
            bindEntry(0, resource: object("buffer", uniformBuffer)),
            bindEntry(1, resource: sampler(for: interpolationMode)),
            bindEntry(2, resource: texture.createView!()),
            bindEntry(3, resource: sampledTexture.createView!())
        )
        return device!.createBindGroup!(object("layout", pipeline.getBindGroupLayout!(0), "entries", entries)).object!
    }

    private func presentBindGroup(texture: JSObject) -> JSObject {
        let entries = array(
            bindEntry(0, resource: sampler(for: interpolationMode)),
            bindEntry(1, resource: texture.createView!())
        )
        return device!.createBindGroup!(object("layout", presentPipeline!.getBindGroupLayout!(0), "entries", entries)).object!
    }

    private func bindEntry(_ binding: Int, resource: ConvertibleToJSValue) -> JSObject {
        object("binding", binding, "resource", resource)
    }

    private func sampler(for mode: InterpolationMode) -> JSObject {
        switch mode {
        case .nearest: nearestSampler!
        case .linear: linearSampler!
        }
    }

    func configureCanvasContext() {
        guard let context, let device else { return }
        _ = context.configure!(object("device", device, "format", canvasFormat, "alphaMode", "opaque"))
    }
}

enum RenderMaterial {
    case color
    case texture(JSObject)
    var texture: JSObject? { if case .texture(let value) = self { value } else { nil } }
    var useTexture: Bool { texture != nil }
    var isColor: Bool { texture == nil }
}

enum PreparedBatch {
    case items(material: RenderMaterial, blendMode: BlendMode, startIndex: Int, instanceCount: Int)
    var material: RenderMaterial {
        switch self { case .items(let value, _, _, _): value }
    }
    var blendMode: BlendMode {
        switch self { case .items(_, let value, _, _): value }
    }
    var startIndex: Int {
        switch self { case .items(_, _, let value, _): value }
    }
    var instanceCount: Int {
        switch self { case .items(_, _, _, let value): value }
    }
}

let itemStride = 36
let itemStrideBytes = itemStride * MemoryLayout<Float>.stride
let uniformBufferSize = 32
let quadVertices: [Float] = [0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1]

let gpuBufferUsageCopyDst = 0x0008
let gpuBufferUsageUniform = 0x0040
let gpuBufferUsageVertex = 0x0020
let gpuTextureUsageCopySrc = 0x01
let gpuTextureUsageCopyDst = 0x02
let gpuTextureUsageTextureBinding = 0x04
let gpuTextureUsageRenderAttachment = 0x10

func object(_ values: Any...) -> JSObject {
    let result = JSObject.global.Object.object!.new()
    var index = 0
    while index + 1 < values.count {
        let key = values[index] as! String
        result[key] = jsValue(values[index + 1])
        index += 2
    }
    return result
}

func array(_ values: ConvertibleToJSValue...) -> JSObject {
    let result = JSObject.global.Array.object!.new()
    for value in values { _ = result.push!(value) }
    return result
}

private func jsValue(_ value: Any) -> JSValue {
    switch value {
    case let value as JSValue: value
    case let value as JSObject: .object(value)
    case let value as String: .string(value)
    case let value as Int: .number(Double(value))
    case let value as Double: .number(value)
    case let value as Bool: .boolean(value)
    default: fatalError("Unsupported JavaScript value")
    }
}
