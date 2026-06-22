import Swift

public struct Game {
    public let logicalResolution: Vec2
    public let interpolationMode: InterpolationMode
    public let preferredFps: Double
    public private(set) var clearColor: Color = .white

    private var players: [Player]
    private let tilemap: Tilemap

    private var sounds: [Sound] = []
    public let soundAssets: [SoundAsset] = [.jump]

    private var spriteBuffer: [Sprite] = []
    public var sprites: [Sprite] { spriteBuffer }
    public let spriteAssets: [SpriteAsset] = [.player]

    public init(
        logicalResolution: Vec2 = .init(x: 480, y: 320),
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 60
    ) {
        self.logicalResolution = logicalResolution
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.players = [.default]

        self.tilemap = .boundary(
            worldSize: logicalResolution,
            tileSize: Vec2(x: 16, y: 16)
        )

        for index in players.indices {
            players[index].place(in: logicalResolution)
        }

        rebuildSpriteBuffer()
    }

    public mutating func update(delta: Double, input: Input) {
        var context = Context(
            delta: delta,
            input: input,
            tilemap: tilemap
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
        for y in 0..<tilemap.rows {
            for x in 0..<tilemap.columns {
                guard let tile = tilemap.tile(x: x, y: y),
                      tile.kind != .empty
                else {
                    continue
                }

                spriteBuffer.append(
                    Sprite(
                        position: Vec2(
                            x: Double(x) * tilemap.tileSize.x,
                            y: Double(y) * tilemap.tileSize.y
                        ),
                        size: tilemap.tileSize,
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
}

private extension Tilemap {
    static func boundary(worldSize: Vec2, tileSize: Vec2) -> Tilemap {
        let columns = Int(worldSize.x / tileSize.x)
        let rows = Int(worldSize.y / tileSize.y)
        let wall = Tilemap.Tile(
            kind: .wall,
            material: .color(.red),
            collider: Collider(
                bounds: Rect(
                    origin: .zero,
                    size: tileSize
                )
            )
        )

        var tilemap = Tilemap(
            columns: columns,
            rows: rows,
            tileSize: tileSize,
            fill: .empty
        )

        for x in 0..<columns {
            tilemap[x, 0] = wall
            tilemap[x, rows - 1] = wall
        }

        for y in 0..<rows {
            tilemap[0, y] = wall
            tilemap[columns - 1, y] = wall
        }

        return tilemap
    }
}

extension Game {
    struct Context {
        let delta: Double
        let input: Input
        private let collisionWorld: CollisionWorld
        fileprivate private(set) var sounds: [Sound] = []

        init(delta: Double, input: Input, tilemap: Tilemap) {
            self.delta = max(delta, 0)
            self.input = input
            self.collisionWorld = CollisionWorld(
                tilemap: tilemap,
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
