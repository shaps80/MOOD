import Swift

public struct Game {
    public let logicalResolution: Vec2
    public let interpolationMode: InterpolationMode
    public let preferredFps: Double
    public private(set) var clearColor: Color = .white
    public var camera: Camera { cameraRig.camera }
    public var renderView: RenderView {
        RenderView(
            origin: camera.origin,
            size: camera.viewportSize,
            padding: debugOptions.contains(.visibility)
                ? .init(horizontal: 80, vertical: 72)
                : .zero
        )
    }

    private let level: Level
    private var players: [Player]
    private var entities: EntityStore
    private var cameraRig: CameraRig
    private var wasResetPressed = false
    private var wasDebugTogglePressed = false
    private var debugOptions: DebugOptions = []

    private var sounds: [Sound] = []
    public let soundAssets: [SoundAsset] = [.jump]

    private var renderContext = RenderContext()
    public var renderCommands: [RenderCommand] { renderContext.commands }
    public let spriteAssets: [SpriteAsset] = [.player]

    public init(
        logicalResolution: Vec2 = .init(x: 800, y: 400),
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 120
    ) {
        self.logicalResolution = logicalResolution
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.players = [Player(entityID: .player)]
        self.entities = EntityStore()

        self.level = .level2(
            worldSize: Vec2(
                x: logicalResolution.x * 2,
                y: logicalResolution.y
            ),
            tileSize: Vec2(x: 16, y: 16)
        )

        self.cameraRig = CameraRig(
            camera: Camera(viewportSize: logicalResolution),
            anchor: .entities([.player]),
            constraints: CameraConstraints(bounds: level.bounds)
        )

        for player in players {
            var entity = player.makeEntity()

            player.place(entity: &entity, at: level.spawnPoint)
            entities.insert(entity)
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
            debugOptions.toggle(.visibility)
            debugOptions.toggle(.colliders)
        }

        var context = Context(
            delta: delta,
            input: input,
            level: level
        )

        for index in players.indices {
            entities.modify(players[index].entityID) { entity in
                players[index].update(context: &context, entity: &entity)
            }
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
        renderContext.removeAll(keepingCapacity: true)

        appendTileSprites(to: &renderContext)
        appendPlayerSprites(to: &renderContext)

        if debugOptions.contains(.colliders) {
            appendColliderDebug(to: &renderContext)
        }

        if debugOptions.contains(.visibility) {
            renderContext.stroke(
                renderView.visibleBounds,
                color: Color(red: 0, green: 0.8, blue: 1, alpha: 0.5),
                width: 2
            )
        }
    }

    private func appendTileSprites(to context: inout RenderContext) {
        for y in 0..<level.tilemap.rows {
            for x in 0..<level.tilemap.columns {
                guard let tile = level.tilemap.tile(x: x, y: y),
                      tile.kind != .empty
                else {
                    continue
                }

                context.sprite(
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

    private func appendPlayerSprites(to context: inout RenderContext) {
        for player in players {
            guard let entity = entities[player.entityID] else {
                continue
            }

            context.sprite(player.sprite(for: entity))
        }
    }

    private func appendColliderDebug(to context: inout RenderContext) {
        let color = Color.green.opacity(0.35)

        level.tilemap.colliderIndex.forEach { collider in
            context.fill(collider.bounds, color: color)
        }

        for player in players {
            guard let entity = entities[player.entityID],
                  let bounds = entity.colliderWorldBounds else {
                continue
            }

            context.fill(bounds, color: color)
        }
    }

    private mutating func resetPlayers() {
        for player in players {
            guard var entity = entities[player.entityID] else {
                continue
            }

            player.place(entity: &entity, at: level.spawnPoint)
            entities.insert(entity)
        }
    }

    private mutating func updateCamera() {
        cameraRig.update(anchorBounds: entityBounds)
    }

    private func entityBounds(for id: Entity.ID) -> Rect? {
        entities.bounds(for: id)
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
