import Swift

public struct PositionedSprite: Equatable, Sendable {
    public var sprite: Sprite
    public var position: Vec2

    public init(sprite: Sprite, position: Vec2) {
        self.sprite = sprite
        self.position = position
    }
}
