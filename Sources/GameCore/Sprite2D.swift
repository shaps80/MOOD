import Swift

public struct Sprite2D: Equatable, Sendable {
    public enum Material: Equatable, Sendable {
        case color(Color)
        case sprite(SpriteID)
    }

    public let position: Vec2
    public let size: Vec2
    public let material: Material

    public init(position: Vec2, size: Vec2, material: Material) {
        self.position = position
        self.size = size
        self.material = material
    }
}
