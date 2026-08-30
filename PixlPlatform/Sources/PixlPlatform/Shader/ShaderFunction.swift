import Swift

/// The backend entry-point name of one shader function.
public struct ShaderFunction: Sendable {
    /// Nonempty shader entry-point name.
    public let name: String

    /// Creates a shader-function reference by name.
    /// - Parameter name: Nonempty entry-point name understood by each adapter.
    public init(name: String) {
        precondition(!name.isEmpty, "Shader function name must not be empty")
        self.name = name
    }
}

public extension ShaderFunction {
    /// Built-in general vertex entry point.
    static let vertex = Self(name: "pixlVertex")
    /// Built-in general fragment entry point.
    static let fragment = Self(name: "pixlFragment")
    static let spriteFragment = Self(name: "pixlSpriteFragment")
    /// Built-in instanced-sprite vertex entry point.
    static let spriteVertex = Self(name: "pixlSpriteVertex")
    /// Built-in instanced analytic-shape vertex entry point.
    static let shapeVertex = Self(name: "pixlShapeVertex")
    /// Built-in analytic signed-distance shape fragment entry point.
    static let shapeFragment = Self(name: "pixlShapeFragment")
    /// Built-in gradient analytic-shape fragment entry point.
    static let gradientShapeFragment = Self(name: "pixlGradientShapeFragment")
    /// Built-in point-defined analytic-shape vertex entry point.
    static let extendedShapeVertex = Self(name: "pixlExtendedShapeVertex")
    /// Built-in point-defined signed-distance shape fragment entry point.
    static let extendedShapeFragment = Self(name: "pixlExtendedShapeFragment")
    /// Built-in point-defined gradient shape fragment entry point.
    static let gradientExtendedShapeFragment = Self(name: "pixlGradientExtendedShapeFragment")
    /// Built-in immediate two-dimensional primitive vertex entry point.
    static let primitiveShapeVertex = Self(name: "pixlPrimitiveShapeVertex")
    /// Built-in immediate two-dimensional primitive fragment entry point.
    static let primitiveShapeFragment = Self(name: "pixlPrimitiveShapeFragment")
    /// Built-in instanced indexed-polygon vertex entry point.
    static let polygonVertex = Self(name: "pixlPolygonVertex")
    /// Built-in solid-colour indexed-polygon fragment entry point.
    static let polygonFragment = Self(name: "pixlPolygonFragment")
    /// Built-in gradient indexed-polygon fragment entry point.
    static let gradientPolygonFragment = Self(name: "pixlGradientPolygonFragment")
    /// Built-in texture-backed indexed-polygon fragment entry point.
    static let texturedPolygonFragment = Self(name: "pixlTexturedPolygonFragment")
}
