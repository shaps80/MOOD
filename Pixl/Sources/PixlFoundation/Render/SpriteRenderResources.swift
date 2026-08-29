import PixlPlatform

private struct SpriteVertex: BitwiseCopyable {
    let position: SIMD2<Float>
    let textureCoordinate: SIMD2<Float>
}

private struct PrimitiveVertex: BitwiseCopyable {
    let position: SIMD2<Float>
    let previous: SIMD2<Float>
    let next: SIMD2<Float>
    let side: Float
}

package struct PrimitiveGeometryRange {
    let indexCount: UInt32
    let indexBufferOffset: UInt64
    let baseVertex: Int32
}

package struct PrimitiveGeometryResources {
    let vertex: Buffer
    let index: Buffer
    let ranges: [PrimitiveGeometryRange]
}

package struct ResolvedSpriteMaterial {
    let texture: Texture
    let sampler: Sampler
}

private struct SpritePipelineKey: Hashable {
    let format: PixelFormat
    let blendMode: BlendMode
    let usesGradient: Bool
}

/// Device-wide 2D rendering resources shared by render-queue workspaces.
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
    private var shapePipelines: [SpritePipelineKey: RenderPipeline] = [:]
    private var extendedShapePipelines: [SpritePipelineKey: RenderPipeline] = [:]
    private var primitivePipelines: [PixelFormat: RenderPipeline] = [:]
    private var vertexBuffer: Buffer?
    private var indexBuffer: Buffer?
    private var primitiveGeometryResources: PrimitiveGeometryResources?
    private var gradientAtlas: Texture?
    private var gradientSampler: Sampler?
    private var gradientGeneration = UInt64.max
    private var retiredGradientAtlases: [Texture] = []

    /// Creates shared sprite and analytic-shape rendering resources.
    /// - Parameters:
    ///   - device: Device used to create and destroy 2D GPU resources.
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
        if let primitiveGeometryResources {
            device.destroy(primitiveGeometryResources.vertex)
            device.destroy(primitiveGeometryResources.index)
        }
        for sampler in samplers.values { device.destroy(sampler) }
        for pipeline in pipelines.values { device.destroy(pipeline) }
        for pipeline in shapePipelines.values { device.destroy(pipeline) }
        for pipeline in extendedShapePipelines.values { device.destroy(pipeline) }
        for pipeline in primitivePipelines.values { device.destroy(pipeline) }
        if let gradientAtlas { device.destroy(gradientAtlas) }
        for texture in retiredGradientAtlases { device.destroy(texture) }
        if let gradientSampler { device.destroy(gradientSampler) }
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
            blendMode: blendMode,
            usesGradient: false
        )
        if let pipeline = pipelines[key] { return pipeline }
        let pipeline = try device.makeRenderPipeline(
            .init(
                vertex: .spriteVertex,
            fragment: .spriteFragment,
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

    package func shapePipeline(
        format: PixelFormat,
        blendMode: BlendMode,
        usesGradient: Bool
    ) throws -> RenderPipeline {
        let key = SpritePipelineKey(
            format: format,
            blendMode: blendMode,
            usesGradient: usesGradient
        )
        if let pipeline = shapePipelines[key] { return pipeline }
        let pipeline = try device.makeRenderPipeline(
            .init(
                vertex: .shapeVertex,
                fragment: usesGradient ? .gradientShapeFragment : .shapeFragment,
                vertexLayout: Self.shapeVertexLayout,
                colorFormat: format,
                blendMode: blendMode
            )
        )
        shapePipelines[key] = pipeline
        return pipeline
    }

    package func extendedShapePipeline(
        format: PixelFormat,
        blendMode: BlendMode,
        usesGradient: Bool
    ) throws -> RenderPipeline {
        let key = SpritePipelineKey(
            format: format,
            blendMode: blendMode,
            usesGradient: usesGradient
        )
        if let pipeline = extendedShapePipelines[key] { return pipeline }
        let pipeline = try device.makeRenderPipeline(
            .init(
                vertex: .extendedShapeVertex,
                fragment: usesGradient
                    ? .gradientExtendedShapeFragment
                    : .extendedShapeFragment,
                vertexLayout: Self.extendedShapeVertexLayout,
                colorFormat: format,
                blendMode: blendMode
            )
        )
        extendedShapePipelines[key] = pipeline
        return pipeline
    }

    package func primitivePipeline(format: PixelFormat) throws -> RenderPipeline {
        if let pipeline = primitivePipelines[format] { return pipeline }
        let pipeline = try device.makeRenderPipeline(
            .init(
                vertex: .primitiveShapeVertex,
                fragment: .primitiveShapeFragment,
                vertexLayout: Self.primitiveVertexLayout,
                colorFormat: format,
                blendMode: .premultiplied
            )
        )
        primitivePipelines[format] = pipeline
        return pipeline
    }

    package func primitiveGeometry() throws -> PrimitiveGeometryResources {
        if let primitiveGeometryResources { return primitiveGeometryResources }

        var vertices: [PrimitiveVertex] = []
        var indices: [UInt16] = []
        var ranges: [PrimitiveGeometryRange] = []

        func appendFill(_ points: [SIMD2<Float>]) {
            let vertexStart = vertices.count
            let indexStart = indices.count
            if points.count == 4 {
                for point in points {
                    vertices.append(.init(position: point, previous: point, next: point, side: 0))
                }
                indices.append(contentsOf: [0, 1, 2, 0, 2, 3])
            } else {
                vertices.append(.init(
                    position: .init(repeating: 0.5),
                    previous: .init(repeating: 0.5),
                    next: .init(repeating: 0.5),
                    side: 0
                ))
                for point in points {
                    vertices.append(.init(position: point, previous: point, next: point, side: 0))
                }
                for index in points.indices {
                    indices.append(0)
                    indices.append(UInt16(index + 1))
                    indices.append(UInt16((index + 1) % points.count + 1))
                }
            }
            ranges.append(.init(
                indexCount: UInt32(indices.count - indexStart),
                indexBufferOffset: UInt64(indexStart * MemoryLayout<UInt16>.stride),
                baseVertex: Int32(vertexStart)
            ))
        }

        func appendStroke(_ points: [SIMD2<Float>]) {
            let vertexStart = vertices.count
            let indexStart = indices.count
            for index in points.indices {
                let previous = points[(index + points.count - 1) % points.count]
                let point = points[index]
                let next = points[(index + 1) % points.count]
                vertices.append(.init(position: point, previous: previous, next: next, side: 1))
                vertices.append(.init(position: point, previous: previous, next: next, side: -1))
            }
            for index in points.indices {
                let next = (index + 1) % points.count
                let outer = UInt16(index * 2)
                let inner = outer + 1
                let nextOuter = UInt16(next * 2)
                let nextInner = nextOuter + 1
                indices.append(contentsOf: [outer, inner, nextInner, outer, nextInner, nextOuter])
            }
            ranges.append(.init(
                indexCount: UInt32(indices.count - indexStart),
                indexBufferOffset: UInt64(indexStart * MemoryLayout<UInt16>.stride),
                baseVertex: Int32(vertexStart)
            ))
        }

        let rectangle: [SIMD2<Float>] = [
            .init(0, 0), .init(1, 0), .init(1, 1), .init(0, 1)
        ]
        var ellipse: [SIMD2<Float>] = []
        ellipse.reserveCapacity(32)
        var ellipsePoint = SIMD2<Float>(0.5, 0)
        let stepCosine: Float = 0.98078528
        let stepSine: Float = 0.19509032
        for _ in 0..<32 {
            ellipse.append(ellipsePoint + 0.5)
            ellipsePoint = .init(
                ellipsePoint.x * stepCosine - ellipsePoint.y * stepSine,
                ellipsePoint.x * stepSine + ellipsePoint.y * stepCosine
            )
        }
        appendFill(rectangle)
        appendStroke(rectangle)
        appendFill(ellipse)
        appendStroke(ellipse)

        let vertexBuffer = try vertices.withUnsafeBytes {
            try device.makeBuffer(copying: $0, usage: .vertex, memory: .gpuOnly)
        }
        do {
            let indexBuffer = try indices.withUnsafeBytes {
                try device.makeBuffer(copying: $0, usage: .index, memory: .gpuOnly)
            }
            let resources = PrimitiveGeometryResources(
                vertex: vertexBuffer,
                index: indexBuffer,
                ranges: ranges
            )
            primitiveGeometryResources = resources
            return resources
        } catch {
            device.destroy(vertexBuffer)
            throw error
        }
    }

    package func gradientResources(
        for execution: RenderQueue.Execution
    ) throws -> (texture: Texture, sampler: Sampler) {
        if gradientGeneration != execution.gradientGeneration {
            var bytes = [UInt8](execution.gradientAtlas)
            bytes.append(contentsOf: repeatElement(
                0,
                count: (execution.queue.settings.gradientCapacity - execution.gradientCount)
                    * 256 * 4
            ))
            let texture = try device.makeTexture(
                copying: bytes,
                descriptor: .init(
                    size: .init(
                        width: 256,
                        height: execution.queue.settings.gradientCapacity
                    ),
                    format: .rgba8Unorm,
                    usage: [.sampled, .copyDestination]
                ),
                bytesPerRow: 256 * 4
            )
            if let gradientAtlas { retiredGradientAtlases.append(gradientAtlas) }
            gradientAtlas = texture
            gradientGeneration = execution.gradientGeneration
        }
        if gradientSampler == nil {
            gradientSampler = try device.makeSampler(.init(
                minFilter: .linear,
                magFilter: .linear
            ))
        }
        return (gradientAtlas!, gradientSampler!)
    }

    private static var vertexLayout: VertexLayout {
        let layout = VertexLayout(
            bufferCapacity: 2,
            attributeCapacity: 9
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
        layout.append(
            .init(
                location: 9,
                bufferIndex: 1,
                format: .uint32,
                offset: 44
            )
        )
        return layout
    }

    private static var shapeVertexLayout: VertexLayout {
        let layout = VertexLayout(bufferCapacity: 2, attributeCapacity: 11)
        layout.append(.init(bufferIndex: 0, stride: UInt64(MemoryLayout<SpriteVertex>.stride)))
        layout.append(.init(
            bufferIndex: 3,
            stride: UInt64(MemoryLayout<RenderQueue.ShapeInstance>.stride),
            stepMode: .perInstance
        ))
        layout.append(.init(location: 0, bufferIndex: 0, format: .float32x2, offset: 0))
        layout.append(.init(location: 2, bufferIndex: 0, format: .float32x2, offset: 8))
        for index in 0..<3 {
            layout.append(.init(
                location: UInt32(index + 3), bufferIndex: 3,
                format: .float32x2, offset: UInt64(index * 8)
            ))
        }
        for index in 0..<4 {
            layout.append(.init(
                location: UInt32(index + 6), bufferIndex: 3,
                format: .float32x4, offset: UInt64(32 + index * 16)
            ))
        }
        layout.append(.init(
            location: 10, bufferIndex: 3,
            format: .float32x2, offset: 24
        ))
        return layout
    }

    private static var extendedShapeVertexLayout: VertexLayout {
        let layout = VertexLayout(bufferCapacity: 2, attributeCapacity: 12)
        layout.append(.init(bufferIndex: 0, stride: UInt64(MemoryLayout<SpriteVertex>.stride)))
        layout.append(.init(
            bufferIndex: 4,
            stride: UInt64(MemoryLayout<RenderQueue.ExtendedShapeInstance>.stride),
            stepMode: .perInstance
        ))
        layout.append(.init(location: 0, bufferIndex: 0, format: .float32x2, offset: 0))
        layout.append(.init(location: 2, bufferIndex: 0, format: .float32x2, offset: 8))
        for index in 0..<3 {
            layout.append(.init(
                location: UInt32(index + 3), bufferIndex: 4,
                format: .float32x2, offset: UInt64(index * 8)
            ))
        }
        for index in 0..<5 {
            layout.append(.init(
                location: UInt32(index + 6), bufferIndex: 4,
                format: .float32x4, offset: UInt64(32 + index * 16)
            ))
        }
        layout.append(.init(
            location: 11, bufferIndex: 4,
            format: .float32x2, offset: 24
        ))
        return layout
    }

    private static var primitiveVertexLayout: VertexLayout {
        let layout = VertexLayout(bufferCapacity: 2, attributeCapacity: 11)
        layout.append(.init(
            bufferIndex: 0,
            stride: UInt64(MemoryLayout<PrimitiveVertex>.stride)
        ))
        layout.append(.init(
            bufferIndex: 5,
            stride: UInt64(MemoryLayout<RenderQueue.PrimitiveInstance>.stride),
            stepMode: .perInstance
        ))
        layout.append(.init(location: 0, bufferIndex: 0, format: .float32x2, offset: 0))
        layout.append(.init(location: 1, bufferIndex: 0, format: .float32x2, offset: 8))
        layout.append(.init(location: 2, bufferIndex: 0, format: .float32x2, offset: 16))
        layout.append(.init(location: 3, bufferIndex: 0, format: .float32, offset: 24))
        for index in 0..<5 {
            layout.append(.init(
                location: UInt32(index + 4),
                bufferIndex: 5,
                format: .float32x2,
                offset: UInt64(index * 8)
            ))
        }
        layout.append(.init(location: 9, bufferIndex: 5, format: .float32, offset: 40))
        layout.append(.init(location: 10, bufferIndex: 5, format: .unorm8x4, offset: 44))
        return layout
    }

}
