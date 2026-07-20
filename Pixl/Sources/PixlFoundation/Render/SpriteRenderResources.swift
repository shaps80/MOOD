import PixlPlatform

private struct SpriteVertex: BitwiseCopyable {
    let position: SIMD2<Float>
    let textureCoordinate: SIMD2<Float>
}

package struct ResolvedSpriteMaterial {
    let texture: Texture
    let sampler: Sampler
}

private struct SpritePipelineKey: Hashable {
    let format: PixelFormat
    let blendMode: BlendMode
}

/// Device-wide sprite rendering resources shared by render-queue workspaces.
///
/// This owner retains the logical texture store and lazily owns the geometry,
/// samplers, and render pipelines required by its workspaces. Encoding through
/// workspaces sharing one owner must be serialized. Destroy the owner only
/// after previously recorded GPU work has completed.
public final class SpriteRenderResources {
    private let device: any Device
    private let textures: TextureResources
    private var samplers: [SamplerDescriptor: Sampler] = [:]
    private var pipelines: [SpritePipelineKey: RenderPipeline] = [:]
    private var vertexBuffer: Buffer?
    private var indexBuffer: Buffer?

    /// Creates shared sprite rendering resources.
    /// - Parameters:
    ///   - device: Device used to create and destroy sprite GPU resources.
    ///   - textures: Store resolving logical sprite texture identities. Its
    ///     textures must belong to `device`.
    public init(
        device: any Device,
        textures: TextureResources
    ) {
        self.device = device
        self.textures = textures
    }

    deinit {
        if let vertexBuffer { device.destroy(vertexBuffer) }
        if let indexBuffer { device.destroy(indexBuffer) }
        for sampler in samplers.values { device.destroy(sampler) }
        for pipeline in pipelines.values { device.destroy(pipeline) }
    }

    /// Creates fixed-capacity encoding storage permanently paired with one render queue.
    /// - Parameter queue: Queue whose capacity and material slots define the workspace.
    /// - Returns: A workspace retaining this shared resource owner and `queue`.
    public func makeWorkspace(for queue: RenderQueue) -> SpriteRenderWorkspace {
        SpriteRenderWorkspace(resources: self, queue: queue)
    }

    package func resolve(
        _ source: RenderQueue.Material
    ) throws -> ResolvedSpriteMaterial {
        guard let texture = textures.texture(for: source.texture) else {
            preconditionFailure(
                "Sprite texture does not belong to these render resources"
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
            sampler: sampler
        )
        return value
    }

    package func pipeline(
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

    package func geometry() throws -> (vertex: Buffer, index: Buffer) {
        if let vertexBuffer, let indexBuffer {
            return (vertexBuffer, indexBuffer)
        }
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
        return (vertexBuffer, indexBuffer!)
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

}
