import Swift

public struct Game {
    public let size: Vec2
    public let interpolationMode: InterpolationMode
    public let preferredFps: Double
    public private(set) var clearColor: Color = .white

    private var players: [Player]

    private var sounds: [Sound] = []
    public let soundAssets: [SoundAsset] = [.jump]

    public var sprites: [Sprite] { players.map(\.sprite) }
    public let spriteAssets: [SpriteAsset] = [.player]

    public init(
        width: Double = 1280,
        height: Double = 720,
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
