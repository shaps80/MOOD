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
    public let blendMode: BlendMode

    public init(
        vertex: ShaderFunction,
        fragment: ShaderFunction,
        vertexLayout: VertexLayout,
        colorFormat: PixelFormat,
        blendMode: BlendMode = .replace
    ) {
        self.vertex = vertex
        self.fragment = fragment
        self.vertexLayout = vertexLayout
        self.colorFormat = colorFormat
        self.blendMode = blendMode
    }
}

/// Fixed-function composition applied by a render pipeline's color attachment.
public enum BlendMode: Hashable, Sendable {
    /// Replaces the destination with the fragment output.
    case replace

    /// Straight-alpha source-over composition.
    case normal
}

public enum PrimitiveTopology: Hashable, Sendable {
    case point
    case line
    case lineStrip
    case triangle
    case triangleStrip
}
