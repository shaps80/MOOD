import Swift

public struct Game {
    public let size: Vec2
    public let interpolationMode: InterpolationMode
    public let preferredFps: Double
    public private(set) var clearColor: Color = .white

    private var players: [Player]

    private var sounds: [Sound] = []
    public let soundAssets: [SoundAsset] = [.jump]

    private var spriteBuffer: [Sprite]
    public var sprites: [Sprite] { spriteBuffer }
    public let spriteAssets: [SpriteAsset] = [.player]

    public init(
        width: Double = 480,
        height: Double = 320,
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 60
    ) {
        self.size = Vec2(x: width, y: height)
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.players = [.default]
        self.spriteBuffer = []
        self.spriteBuffer.reserveCapacity(players.count)

        for index in players.indices {
            players[index].place(in: size)
        }

        rebuildSpriteBuffer()
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
        rebuildSpriteBuffer()
    }

    public mutating func drainSounds() -> [Sound] {
        defer {
            sounds.removeAll(keepingCapacity: true)
        }

        return sounds
    }

    private mutating func rebuildSpriteBuffer() {
        spriteBuffer.removeAll(keepingCapacity: true)

        for player in players {
            spriteBuffer.append(player.sprite)
        }
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
