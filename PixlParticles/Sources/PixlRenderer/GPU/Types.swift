import Swift

public enum BufferMemory: Sendable {
    case cpuVisible
    case gpuOnly
}

public enum PixelFormat: Sendable {
    case rgba16Float
    case depth32Float
}

public enum BlendMode: Sendable {
    case premultiplied
}

public enum CompareFunction: Sendable {
    case less
}

public enum Primitive: Sendable {
    case point
}

public struct ThreadGrid: Sendable {
    public let width: Int
    public let height: Int
    public let depth: Int

    public init(width: Int, height: Int = 1, depth: Int = 1) {
        self.width = width
        self.height = height
        self.depth = depth
    }
}

public struct RenderPipelineDescriptor: Sendable {
    public let vertexFunction: String
    public let fragmentFunction: String
    public let colorFormat: PixelFormat
    public let depthFormat: PixelFormat
    public let blendMode: BlendMode

    public init(
        vertexFunction: String,
        fragmentFunction: String,
        colorFormat: PixelFormat,
        depthFormat: PixelFormat,
        blendMode: BlendMode
    ) {
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.colorFormat = colorFormat
        self.depthFormat = depthFormat
        self.blendMode = blendMode
    }
}
