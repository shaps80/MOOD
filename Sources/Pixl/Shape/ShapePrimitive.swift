import Swift

public enum ShapePrimitiveKind: Int, Equatable, Sendable {
    case rect = 0
    case roundedRect = 1
    case ellipse = 2
    case line = 3
}

public struct ShapePrimitive: Equatable, Sendable {
    public var kind: ShapePrimitiveKind
    public var bounds: Rect
    public var radius: Double
    public var lineStart: Vec2
    public var lineEnd: Vec2
    public var fillColor: Color
    public var strokeColor: Color
    public var strokeWidth: Double
    public var lineCap: LineCap
    public var fillAntialiased: Bool
    public var strokeAntialiased: Bool
    public var blendMode: BlendMode
    public var layer: RenderLayer
}
