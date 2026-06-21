import Swift

public struct Entity: Equatable, Sendable {
    internal var size: Vec2
    internal var position: Vec2
    internal var velocity: Vec2
    internal let asset: SpriteAsset

    public init(position: Vec2, size: Vec2, asset: SpriteAsset) {
        self.position = position
        self.size = size
        self.velocity = .zero
        self.asset = asset
    }

    public var sprite: Sprite2D {
        Sprite2D(
            position: position,
            size: size,
            material: .sprite(asset.id)
        )
    }

    mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
    }
}
