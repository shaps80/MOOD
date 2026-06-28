import Swift

public enum RenderPrimitive: Equatable, Sendable {
    case sprite(PositionedSprite)
    case shape(ShapePrimitive)
}
