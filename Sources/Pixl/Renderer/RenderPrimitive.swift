import Swift

public enum RenderPrimitive: Equatable, Sendable {
    case sprite(Sprite)
    case shape(ShapePrimitive)
}
