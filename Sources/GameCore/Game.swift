import Swift

public struct Game {
    public let logicalResolution: Vec2
    public let interpolationMode: InterpolationMode
    public let preferredFps: Double
    public private(set) var clearColor: Color = .white
    public var camera: Camera { cameraRig.camera }

    private let level: Level
    private var players: [Player]
    private var cameraRig: CameraRig
    private var wasResetPressed = false
    private var wasDebugTogglePressed = false
    private var debugOptions: DebugOptions = []

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
        self.players = [Player(entityID: .player)]

        let level = Level.level2(
            worldSize: Vec2(
                x: logicalResolution.x * 2,
                y: logicalResolution.y
            ),
            tileSize: Vec2(x: 16, y: 16)
        )
        self.level = level
        self.cameraRig = CameraRig(
            camera: Camera(viewportSize: logicalResolution),
            anchor: .entities([.player]),
            constraints: CameraConstraints(bounds: level.bounds)
        )

        for index in players.indices {
            players[index].place(at: level.spawnPoint)
        }

        updateCamera()
        rebuildSpriteBuffer()
    }

    public mutating func update(delta: Double, input: Input) {
        defer {
            wasResetPressed = input.reset
            wasDebugTogglePressed = input.jump
        }

        if input.reset && !wasResetPressed {
            resetPlayers()
        }

        if input.jump && !wasDebugTogglePressed {
            debugOptions.toggle(.colliders)
        }

        var context = Context(
            delta: delta,
            input: input,
            level: level
        )

        for index in players.indices {
            players[index].update(context: &context)
        }

        updateCamera()
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

        if debugOptions.contains(.colliders) {
            appendColliderDebugSprites()
        }
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

    private mutating func appendColliderDebugSprites() {
        let color = Color.green.opacity(0.35)

        level.tilemap.colliderIndex.forEach { collider in
            appendDebugSprite(bounds: collider.bounds, color: color)
        }

        for player in players {
            guard let bounds = player.entity.colliderWorldBounds else {
                continue
            }

            appendDebugSprite(bounds: bounds, color: color)
        }
    }

    private mutating func appendDebugSprite(bounds: Rect, color: Color) {
        spriteBuffer.append(
            Sprite(
                position: bounds.origin,
                size: bounds.size,
                material: .color(color)
            )
        )
    }

    private mutating func resetPlayers() {
        for index in players.indices {
            players[index].place(at: level.spawnPoint)
        }
    }

    private mutating func updateCamera() {
        cameraRig.update(anchorBounds: entityBounds)
    }

    private func entityBounds(for id: Entity.ID) -> Rect? {
        for player in players where player.entity.id == id {
            return player.entity.bounds
        }

        return nil
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
