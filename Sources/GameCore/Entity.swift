import Swift

public struct Entity: Equatable, Sendable {
    public let size: Vec2
    public private(set) var position: Vec2
    public private(set) var velocity: Vec2
    public let asset: SpriteAsset

    public init(position: Vec2, size: Vec2, asset: SpriteAsset) {
        self.position = position
        self.size = size
        self.velocity = Vec2(x: 0, y: 0)
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
