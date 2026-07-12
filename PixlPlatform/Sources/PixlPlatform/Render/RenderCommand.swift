import Swift

package enum RenderCommand {
    case setRenderPipeline(
        ResourceID
    )
    case setVertexBuffer(
        ResourceID,
        offset: UInt64,
        index: UInt32
    )
    case drawPrimitives(
        PrimitiveTopology,
        vertexStart: UInt32,
        vertexCount: UInt32,
        instanceCount: UInt32,
        baseInstance: UInt32
    )
}
