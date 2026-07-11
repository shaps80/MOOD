import Swift

/// A sprite paired with the world transform where it should be drawn.
///
/// `Sprite` describes presentation. Entity/game code provides transform values
/// at draw time so the same sprite value can be reused without embedding world
/// state.
///
/// ```swift
/// RenderCommand.sprite(
///     PositionedSprite(
///         sprite: playerSprite,
///         transform: RenderTransform(center: player.position, size: playerSize)
///     )
/// )
/// ```
public struct PositionedSprite: Equatable, Sendable {
    /// The sprite presentation to draw.
    public var sprite: Sprite

    /// The world-space transform for the sprite.
    public var transform: RenderTransform

    /// The world-space center point for the sprite.
    public var position: Vec2 {
        get {
            transform.center
        }
        set {
            transform.center = newValue
        }
    }

    /// Creates a positioned sprite render payload.
    ///
    /// - Parameters:
    ///   - sprite: The sprite presentation to draw.
    ///   - transform: The world-space transform.
    public init(sprite: Sprite, transform: RenderTransform) {
        self.sprite = sprite
        self.transform = transform
    }

    /// Creates a positioned sprite render payload.
    ///
    /// The size is resolved later from the sprite material and platform texture
    /// metadata.
    ///
    /// - Parameters:
    ///   - sprite: The sprite presentation to draw.
    ///   - position: The world-space center point.
    ///   - rotation: The clockwise rotation in y-down coordinates.
    public init(sprite: Sprite, position: Vec2, rotation: Angle = .zero) {
        self.sprite = sprite
        self.transform = RenderTransform(
            center: position,
            size: .zero,
            rotation: rotation
        )
    }
}
