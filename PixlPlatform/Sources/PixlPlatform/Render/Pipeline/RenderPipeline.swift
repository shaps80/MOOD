import Swift

/// An opaque handle to immutable render-pipeline state.
public struct RenderPipeline: Hashable, Sendable {
    package let id: ResourceID

    package init(id: ResourceID) {
        self.id = id
    }
}

/// Complete portable configuration used to create a render pipeline.
public struct RenderPipelineDescriptor {
    /// Vertex shader entry point.
    public let vertex: ShaderFunction
    /// Fragment shader entry point.
    public let fragment: ShaderFunction
    /// Vertex-buffer and attribute layout consumed by the vertex shader.
    public let vertexLayout: VertexLayout
    /// Pixel format required by the render pass colour attachment.
    public let colorFormat: PixelFormat
    /// Fixed-function colour composition.
    public let blendMode: BlendMode

    /// Creates a render-pipeline description.
    /// - Parameters:
    ///   - vertex: Vertex shader entry point.
    ///   - fragment: Fragment shader entry point.
    ///   - vertexLayout: Vertex-buffer and attribute layout.
    ///   - colorFormat: Required render-target colour format.
    ///   - blendMode: Fixed-function colour composition.
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

/// How a draw groups consecutive vertices or indices into primitives.
public enum PrimitiveTopology: Hashable, Sendable {
    /// Each vertex forms one point.
    case point
    /// Each pair of vertices forms one independent line.
    case line
    /// Each vertex after the first extends a connected line strip.
    case lineStrip
    /// Each group of three vertices forms one independent triangle.
    case triangle
    /// Each vertex after the first two extends a connected triangle strip.
    case triangleStrip
}
