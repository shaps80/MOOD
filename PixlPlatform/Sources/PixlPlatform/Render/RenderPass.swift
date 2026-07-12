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
}
