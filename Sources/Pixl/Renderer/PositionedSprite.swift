import Swift

/// A sprite paired with the world position where it should be drawn.
///
/// `Sprite` describes presentation. Entity/game code provides position at draw
/// time so the same sprite value can be reused without embedding world state.
///
/// ```swift
/// RenderCommand.sprite(PositionedSprite(sprite: playerSprite, position: player.position))
/// ```
public struct PositionedSprite: Equatable, Sendable {
    /// The sprite presentation to draw.
    public var sprite: Sprite

    /// The world-space center point for the sprite.
    public var position: Vec2

    /// Creates a positioned sprite render payload.
    ///
    /// - Parameters:
    ///   - sprite: The sprite presentation to draw.
    ///   - position: The world-space center point.
    public init(sprite: Sprite, position: Vec2) {
        self.sprite = sprite
        self.position = position
    }
}
