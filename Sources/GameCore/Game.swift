import Swift

public struct Game {
    public let size: Vec2
    public let interpolationMode: InterpolationMode
    public private(set) var clearColor = Color(red: 0, green: 0, blue: 0, alpha: 1)
    private var players: [Player]

    public var sprites: [Sprite2D] {
        players.map(\.entity.sprite)
    }

    private var entities: [Entity] {
        players.map { $0.entity }
    }

    public var spriteAssets: [SpriteAsset] {
        entities.reduce(into: []) { assets, entity in
            if !assets.contains(entity.asset) {
                assets.append(entity.asset)
            }
        }
    }

    public init(width: Double = 640, height: Double = 320, interpolationMode: InterpolationMode = .nearest) {
        self.size = Vec2(x: width, y: height)
        self.interpolationMode = interpolationMode
        self.players = [.default]

        for index in players.indices {
            players[index].place(in: size)
        }
    }

    public mutating func update(delta: Double, input: InputState) {
        for index in players.indices {
            players[index].update(
                delta: delta,
                input: input,
                worldSize: size
            )
        }
    }
}
