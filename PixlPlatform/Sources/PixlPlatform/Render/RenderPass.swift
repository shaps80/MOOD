import Swift

public struct RenderPassDescriptor: Sendable {
    public var colorAttachment: ColorAttachment

    public init(_ colorAttachment: ColorAttachment) {
        self.colorAttachment = colorAttachment
    }
}

package struct RecordedRenderPass {
    package var descriptor: RenderPassDescriptor
    package var commandStart: UInt32 = 0
    package var commandCount: UInt32 = 0
    package var hasRenderPipeline = false
}

/// Records one contiguous render-pass command stream into a `Frame`.
///
/// Its interface follows Metal's render-command encoder: configure pipeline
/// and shader resources, then issue primitive draws. The frame owns all
/// recorded storage; retaining the encoder does not retain a native encoder.
public struct RenderPassEncoder {
    private let frame: Frame
    private let passIndex: UInt32

    /// Pixel format required by pipelines encoded into this render pass.
    public var colorFormat: PixelFormat {
        frame.colorFormat(forRenderPassAt: passIndex)
    }

    package init(frame: Frame, passIndex: UInt32) {
        self.frame = frame
        self.passIndex = passIndex
    }

    public func setRenderPipeline(_ pipeline: RenderPipeline) {
        frame.append(.setRenderPipeline(pipeline.id), toRenderPassAt: passIndex)
    }

    public func setVertexBuffer(
        _ buffer: Buffer,
        offset: UInt64 = 0,
        index: UInt32
    ) {
        precondition(offset < buffer.descriptor.size, "Vertex buffer offset is out of bounds")
        frame.append(
            .setVertexBuffer(buffer.id, offset: offset, index: index),
            toRenderPassAt: passIndex
        )
    }

    public func setVertexBytes(
        _ bytes: UnsafeRawBufferPointer,
        index: UInt32
    ) {
        frame.appendVertexBytes(bytes, index: index, toRenderPassAt: passIndex)
    }

    public func setVertexBytes<Value: BitwiseCopyable>(
        of value: Value,
        index: UInt32
    ) {
        var value = value
        Swift.withUnsafeBytes(of: &value) {
            setVertexBytes($0, index: index)
        }
    }

    /// Copies arbitrary per-vertex or per-instance bytes into frame-owned
    /// upload storage and binds that range as a vertex buffer.
    public func setVertexData(
        _ bytes: UnsafeRawBufferPointer,
        index: UInt32
    ) {
        frame.appendVertexData(bytes, index: index, toRenderPassAt: passIndex)
    }

    public func setFragmentTexture(
        _ texture: Texture,
        index: UInt32
    ) {
        precondition(
            texture.descriptor.usage.contains(.sampled),
            "Fragment texture is missing sampled usage"
        )
        frame.append(
            .setFragmentTexture(texture.id, index: index),
            toRenderPassAt: passIndex
        )
    }

    public func setFragmentSampler(
        _ sampler: Sampler,
        index: UInt32
    ) {
        frame.append(
            .setFragmentSampler(sampler.id, index: index),
            toRenderPassAt: passIndex
        )
    }

    public func drawPrimitives(
        _ topology: PrimitiveTopology,
        vertexStart: UInt32 = 0,
        vertexCount: UInt32,
        instanceCount: UInt32 = 1,
        baseInstance: UInt32 = 0
    ) {
        precondition(vertexCount > 0, "Vertex count must be greater than zero")
        precondition(instanceCount > 0, "Instance count must be greater than zero")
        frame.append(
            .drawPrimitives(
                topology,
                vertexStart: vertexStart,
                vertexCount: vertexCount,
                instanceCount: instanceCount,
                baseInstance: baseInstance
            ),
            toRenderPassAt: passIndex
        )
    }

    /// Records an indexed primitive draw.
    ///
    /// - Parameters:
    ///   - topology: Primitive interpretation for indexed vertices.
    ///   - indexCount: Number of indices to read.
    ///   - indexType: Element width stored in `indexBuffer`.
    ///   - indexBuffer: Packed index buffer created with ``BufferUsage/index``.
    ///   - indexBufferOffset: Byte offset of the first index.
    ///   - instanceCount: Number of instances to draw.
    ///   - baseVertex: Value added to each decoded index.
    ///   - baseInstance: First instance identifier.
    public func drawIndexedPrimitives(
        _ topology: PrimitiveTopology,
        indexCount: UInt32,
        indexType: IndexType,
        indexBuffer: Buffer,
        indexBufferOffset: UInt64 = 0,
        instanceCount: UInt32 = 1,
        baseVertex: Int32 = 0,
        baseInstance: UInt32 = 0
    ) {
        precondition(indexBuffer.descriptor.usage.contains(.index), "Index buffer is missing index usage")
        precondition(indexCount > 0, "Index count must be greater than zero")
        precondition(instanceCount > 0, "Instance count must be greater than zero")
        precondition(indexBufferOffset.isMultiple(of: indexType.byteWidth), "Index buffer offset is not aligned to index type")
        let byteCount = UInt64(indexCount) * indexType.byteWidth
        precondition(byteCount <= indexBuffer.descriptor.size, "Index count exceeds index buffer size")
        precondition(indexBufferOffset <= indexBuffer.descriptor.size - byteCount, "Index buffer range is out of bounds")

        frame.append(
            .drawIndexedPrimitives(
                topology,
                indexType: indexType,
                indexBuffer: indexBuffer.id,
                indexBufferOffset: indexBufferOffset,
                indexCount: indexCount,
                instanceCount: instanceCount,
                baseVertex: baseVertex,
                baseInstance: baseInstance
            ),
            toRenderPassAt: passIndex
        )
    }
}
