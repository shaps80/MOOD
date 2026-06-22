import Swift

public struct Game {
    public let logicalResolution: Vec2
    public let interpolationMode: InterpolationMode
    public let preferredFps: Double
    public private(set) var clearColor: Color = .white

    private let level: Level
    private var players: [Player]
    private var wasResetPressed = false

    private var sounds: [Sound] = []
    public let soundAssets: [SoundAsset] = [.jump]

    private var spriteBuffer: [Sprite] = []
    public var sprites: [Sprite] { spriteBuffer }
    public let spriteAssets: [SpriteAsset] = [.player]

    public init(
        logicalResolution: Vec2 = .init(x: 1280, y: 720),
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 60
    ) {
        self.logicalResolution = logicalResolution
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.players = [.default]
        self.level = .level1(
            logicalResolution: logicalResolution,
            tileSize: Vec2(x: 16, y: 16)
        )

        for index in players.indices {
            players[index].place(at: level.spawnPoint)
        }

        rebuildSpriteBuffer()
    }

    public mutating func update(delta: Double, input: Input) {
        defer {
            wasResetPressed = input.reset
        }

        if input.reset && !wasResetPressed {
            resetPlayers()
        }

        var context = Context(
            delta: delta,
            input: input,
            level: level
        )

        for index in players.indices {
            players[index].update(context: &context)
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

        appendTileSprites()
        appendPlayerSprites()
    }

    private mutating func appendTileSprites() {
        for y in 0..<level.tilemap.rows {
            for x in 0..<level.tilemap.columns {
                guard let tile = level.tilemap.tile(x: x, y: y),
                      tile.kind != .empty
                else {
                    continue
                }

                spriteBuffer.append(
                    Sprite(
                        position: Vec2(
                            x: Double(x) * level.tilemap.tileSize.x,
                            y: Double(y) * level.tilemap.tileSize.y
                        ),
                        size: level.tilemap.tileSize,
                        material: tile.material
                    )
                )
            }
        }
    }

    private mutating func appendPlayerSprites() {
        for player in players {
            spriteBuffer.append(player.sprite)
        }
    }

    private mutating func resetPlayers() {
        for index in players.indices {
            players[index].place(at: level.spawnPoint)
        }
    }
}

extension Game {
    struct Context {
        let delta: Double
        let input: Input
        let level: Level
        private let collisionWorld: CollisionWorld
        fileprivate private(set) var sounds: [Sound] = []

        init(delta: Double, input: Input, level: Level) {
            self.delta = max(delta, 0)
            self.input = input
            self.level = level
            self.collisionWorld = CollisionWorld(
                tilemap: level.tilemap,
                delta: delta
            )
        }

        mutating func play(sound: Sound) {
            sounds.append(sound)
        }

        func move(entity: inout Entity, velocity: Vec2) {
            collisionWorld.move(entity: &entity, velocity: velocity)
        }
    }
}
