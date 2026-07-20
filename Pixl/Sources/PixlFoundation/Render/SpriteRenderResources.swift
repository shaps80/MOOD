import PixlPlatform

private struct SpriteVertex: BitwiseCopyable {
    let position: SIMD2<Float>
    let textureCoordinate: SIMD2<Float>
}

private struct SpriteViewParameters: BitwiseCopyable {
    let x: SIMD3<Float>
    let y: SIMD3<Float>
    let translation: SIMD3<Float>
}

private struct ResolvedSpriteMaterial {
    let texture: Texture
    let sampler: Sampler
    var pipelineFormat: PixelFormat?
    var pipeline: RenderPipeline?
}

private struct SpritePipelineKey: Hashable {
    let format: PixelFormat
    let blendMode: BlendMode
}

package final class SpriteRenderResources {
    private let device: any Device
    private let textureForID: (TextureResourceID) -> Texture?
    private let capacity: Int
    private let resolved: UnsafeMutablePointer<ResolvedSpriteMaterial?>
    private let upload: UnsafeMutablePointer<RenderQueue.Instance>
    private var samplers: [SamplerDescriptor: Sampler] = [:]
    private var pipelines: [SpritePipelineKey: RenderPipeline] = [:]
    private var vertexBuffer: Buffer?
    private var indexBuffer: Buffer?

    package init(
        device: any Device,
        capacity: Int,
        textureForID: @escaping (TextureResourceID) -> Texture?
    ) {
        self.device = device
        self.capacity = capacity
        self.textureForID = textureForID
        resolved = .allocate(capacity: capacity)
        resolved.initialize(repeating: nil, count: capacity)
        upload = .allocate(capacity: capacity)
        upload.initialize(
            repeating: RenderQueue.Instance(
                transformX: .zero,
                transformY: .zero,
                translation: .zero,
                textureOrigin: .zero,
                textureScale: .zero,
                tintRGBA8: 0
            ),
            count: capacity
        )
        precondition(
            MemoryLayout<RenderQueue.Instance>.stride == 48,
            "Sprite instance ABI must remain 48 bytes"
        )
    }

    deinit {
        resolved.deinitialize(count: capacity)
        resolved.deallocate()
        upload.deinitialize(count: capacity)
        upload.deallocate()
        if let vertexBuffer { device.destroy(vertexBuffer) }
        if let indexBuffer { device.destroy(indexBuffer) }
        for sampler in samplers.values { device.destroy(sampler) }
        for pipeline in pipelines.values { device.destroy(pipeline) }
    }

    package func encode(
        _ execution: RenderQueue.Execution,
        viewIndex: Int,
        queue: RenderQueue,
        on pass: RenderPassEncoder
    ) throws {
        let view = execution.views[viewIndex]
        guard !view.ordinals.isEmpty else { return }
        try ensureGeometry()

        let instanceStart = ContinuousClock.now
        for index in view.ordinals.indices {
            upload[index] = execution.instances[Int(view.ordinals[index])]
        }
        pass.setVertexBuffer(vertexBuffer!, index: 0)
        pass.setVertexBytes(
            of: SpriteViewParameters(
                x: view.projectionX,
                y: view.projectionY,
                translation: view.projectionTranslation
            ),
            index: 2
        )
        pass.setVertexData(
            UnsafeRawBufferPointer(
                start: upload,
                count: view.ordinals.count
                    * MemoryLayout<RenderQueue.Instance>.stride
            ),
            index: 1
        )
        queue.addInstanceSeconds(
            Self.seconds(since: instanceStart)
        )

        var start = UInt32(0)
        for batch in view.batches {
            let materialIndex = Int(batch.material)
            var material = try resolve(
                execution.materials[materialIndex],
                at: materialIndex
            )
            if material.pipelineFormat != pass.colorFormat {
                material.pipeline = try pipeline(
                    format: pass.colorFormat,
                    blendMode: execution.materials[materialIndex].blendMode
                )
                material.pipelineFormat = pass.colorFormat
                resolved[materialIndex] = material
            }
            pass.setRenderPipeline(material.pipeline!)
            pass.setFragmentTexture(material.texture, index: 0)
            pass.setFragmentSampler(material.sampler, index: 0)
            pass.drawIndexedPrimitives(
                .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: indexBuffer!,
                instanceCount: batch.end - start,
                baseInstance: start
            )
            start = batch.end
        }
    }

    private func resolve(
        _ source: RenderQueue.Material,
        at index: Int
    ) throws -> ResolvedSpriteMaterial {
        if let value = resolved[index] { return value }
        guard let texture = textureForID(source.texture) else {
            preconditionFailure(
                "Sprite texture does not belong to this game context"
            )
        }
        let sampler: Sampler
        if let existing = samplers[source.sampler] {
            sampler = existing
        } else {
            sampler = try device.makeSampler(source.sampler)
            samplers[source.sampler] = sampler
        }
        let value = ResolvedSpriteMaterial(
            texture: texture,
            sampler: sampler,
            pipelineFormat: nil,
            pipeline: nil
        )
        resolved[index] = value
        return value
    }

    private func pipeline(
        format: PixelFormat,
        blendMode: BlendMode
    ) throws -> RenderPipeline {
        let key = SpritePipelineKey(
            format: format,
            blendMode: blendMode
        )
        if let pipeline = pipelines[key] { return pipeline }
        let pipeline = try device.makeRenderPipeline(
            .init(
                vertex: .spriteVertex,
                fragment: .fragment,
                vertexLayout: Self.vertexLayout,
                colorFormat: format,
                blendMode: blendMode
            )
        )
        pipelines[key] = pipeline
        return pipeline
    }

    private func ensureGeometry() throws {
        guard vertexBuffer == nil else { return }
        var vertices = (
            SpriteVertex(
                position: .init(-0.5, 0.5),
                textureCoordinate: .init(0, 0)
            ),
            SpriteVertex(
                position: .init(-0.5, -0.5),
                textureCoordinate: .init(0, 1)
            ),
            SpriteVertex(
                position: .init(0.5, -0.5),
                textureCoordinate: .init(1, 1)
            ),
            SpriteVertex(
                position: .init(0.5, 0.5),
                textureCoordinate: .init(1, 0)
            )
        )
        var indices: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16) = (
            0, 1, 2, 0, 2, 3
        )
        let vertexBuffer = try withUnsafeBytes(of: &vertices) {
            try device.makeBuffer(
                copying: $0,
                usage: .vertex,
                memory: .gpuOnly
            )
        }
        do {
            indexBuffer = try withUnsafeBytes(of: &indices) {
                try device.makeBuffer(
                    copying: $0,
                    usage: .index,
                    memory: .gpuOnly
                )
            }
            self.vertexBuffer = vertexBuffer
        } catch {
            device.destroy(vertexBuffer)
            throw error
        }
    }

    private static var vertexLayout: VertexLayout {
        let layout = VertexLayout(
            bufferCapacity: 2,
            attributeCapacity: 8
        )
        layout.append(
            .init(
                bufferIndex: 0,
                stride: UInt64(MemoryLayout<SpriteVertex>.stride)
            )
        )
        layout.append(
            .init(
                bufferIndex: 1,
                stride: UInt64(MemoryLayout<RenderQueue.Instance>.stride),
                stepMode: .perInstance
            )
        )
        layout.append(
            .init(
                location: 0,
                bufferIndex: 0,
                format: .float32x2,
                offset: 0
            )
        )
        layout.append(
            .init(
                location: 2,
                bufferIndex: 0,
                format: .float32x2,
                offset: 8
            )
        )
        for index in 0..<5 {
            layout.append(
                .init(
                    location: UInt32(index + 3),
                    bufferIndex: 1,
                    format: .float32x2,
                    offset: UInt64(index * 8)
                )
            )
        }
        layout.append(
            .init(
                location: 8,
                bufferIndex: 1,
                format: .unorm8x4,
                offset: 40
            )
        )
        return layout
    }

    private static func seconds(
        since start: ContinuousClock.Instant
    ) -> Double {
        let value = (ContinuousClock.now - start).components
        return Double(value.seconds) + Double(value.attoseconds) * 1e-18
    }
}
