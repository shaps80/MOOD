import Swift

/// Normalized texture coordinates for a sprite draw.
///
/// Values are stored in UV space, where `(0, 0)` is the texture origin and
/// `(1, 1)` is the full texture size.
public struct TextureRect: Equatable, Sendable {
    public var origin: Vec2
    public var size: Vec2

    public init(origin: Vec2, size: Vec2) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            origin: Vec2(x: x, y: y),
            size: Vec2(x: width, y: height)
        )
    }

    public static let full = TextureRect(x: 0, y: 0, width: 1, height: 1)
}
