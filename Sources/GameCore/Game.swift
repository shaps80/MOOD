import Swift

public struct Game {
    public let size: Vec2
    public let interpolationMode: InterpolationMode
    public let preferredFps: Double
    public private(set) var clearColor = Color(red: 0, green: 0, blue: 0, alpha: 1)

    private var players: [Player]
    private var entities: [Entity] { players.map { $0.entity } }

    private var sounds: [Sound] = []
    public let soundAssets: [SoundAsset] = [.jump]

    public var sprites: [Sprite] { players.map(\.entity.sprite) }
    public var spriteAssets: [SpriteAsset] {
        entities.reduce(into: []) { assets, entity in
            if !assets.contains(entity.asset) {
                assets.append(entity.asset)
            }
        }
    }

    public init(
        width: Double = 800,
        height: Double = 600,
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 120
    ) {
        self.size = Vec2(x: width, y: height)
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.players = [.default]

        for index in players.indices {
            players[index].place(in: size)
        }
    }

    public mutating func update(delta: Double, input: Input) {
        var context = Context(input: input, worldSize: size)

        for index in players.indices {
            players[index].update(
                delta: delta,
                context: &context
            )
        }

        sounds.append(contentsOf: context.sounds)
    }

    public mutating func drainSounds() -> [Sound] {
        defer {
            sounds.removeAll(keepingCapacity: true)
        }

        return sounds
    }
}

extension Game {
    public struct Context {
        public let input: Input
        public let worldSize: Vec2
        fileprivate private(set) var sounds = [Sound]()

        public init(input: Input, worldSize: Vec2) {
            self.input = input
            self.worldSize = worldSize
        }

        mutating func play(sound: Sound) {
            sounds.append(sound)
        }
    }
}
