import Swift

public struct RenderPipeline: Hashable, Sendable {
    package let id: ResourceID

    package init(id: ResourceID) {
        self.id = id
    }
}

public struct RenderPipelineDescriptor {
    public let vertex: ShaderFunction
    public let fragment: ShaderFunction
    public let vertexLayout: VertexLayout
    public let colorFormat: PixelFormat

    public init(
        vertex: ShaderFunction,
        fragment: ShaderFunction,
        vertexLayout: VertexLayout,
        colorFormat: PixelFormat
    ) {
        self.vertex = vertex
        self.fragment = fragment
        self.vertexLayout = vertexLayout
        self.colorFormat = colorFormat
    }
}

public enum PrimitiveTopology: Hashable, Sendable {
    case point
    case line
    case lineStrip
    case triangle
    case triangleStrip
}
