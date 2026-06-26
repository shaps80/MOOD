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
    private var players: [Player] = [.init(entityID: .player)]
    private var pickups: [Pickup] = []
    private var entities: EntityStore = .init()
    private var cameraRig: CameraRig
    private var wasResetPressed = false
    private var wasDebugTogglePressed = false
    private var debugOptions: DebugOptions = []

    private var sounds: [Sound] = []
    public let soundAssets: [SoundAsset] = [.jump]

    private var renderContext = RenderContext()
    public var renderCommands: [RenderCommand] { renderContext.commands }
    public private(set) var renderBatches: [RenderBatch] = []
    public private(set) var renderStats = RenderStats()
    public let spriteAssets: [SpriteAsset] = [.player]

    public init(
        logicalResolution: Vec2 = .init(x: 800, y: 400),
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 120
    ) {
        self.logicalResolution = logicalResolution
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS

        self.level = .level2(
            worldSize: Vec2(
                x: logicalResolution.x * 2,
                y: logicalResolution.y
            ),
            tileSize: Vec2(x: 16, y: 16)
        )
        self.pickups = [
            Pickup(
                entityID: .pickup,
                center: Vec2(
                    x: level.spawnPoint.x + (level.tilemap.tileSize.x * 8),
                    y: level.spawnPoint.y
                )
            )
        ]

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

        for pickup in pickups {
            entities.insert(pickup.makeEntity())
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
        let visibleBounds = renderView.visibleBounds
        var visibleTileCount = 0
        var visibleEntityCount = 0

        visibleTileCount += appendTileSprites(visibleWithin: visibleBounds, to: &renderContext)
        visibleEntityCount += appendPlayerSprites(visibleWithin: visibleBounds, to: &renderContext)
        visibleEntityCount += appendPickupSprites(visibleWithin: visibleBounds, to: &renderContext)

        if debugOptions.contains(.colliders) {
            appendColliderDebug(visibleWithin: visibleBounds, to: &renderContext)
        }

        if debugOptions.contains(.visibility) {
            renderContext.stroke(
                visibleBounds,
                color: Color(red: 0, green: 0.8, blue: 1, alpha: 0.5),
                width: 2,
                layer: .debug
            )
        }

        renderContext.sortCommands()
        renderBatches = RenderBatch.make(from: renderContext.commands)
        renderStats = RenderStats(
            commandCount: renderContext.commands.count,
            primitiveCount: renderContext.commands.reduce(into: 0) { count, command in
                count += command.primitiveCount
            },
            batchCount: renderBatches.count,
            visibleTileCount: visibleTileCount,
            visibleEntityCount: visibleEntityCount
        )
    }

    private func appendTileSprites(
        visibleWithin bounds: Rect,
        to context: inout RenderContext
    ) -> Int {
        guard let range = level.tilemap.tileRange(intersecting: bounds) else {
            return 0
        }

        var visibleTileCount = 0

        for y in range.rows {
            for x in range.columns {
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
                    ),
                    layer: tile.layer
                )
                visibleTileCount += 1
            }
        }

        return visibleTileCount
    }

    private func appendPlayerSprites(
        visibleWithin bounds: Rect,
        to context: inout RenderContext
    ) -> Int {
        var visibleEntityCount = 0

        for player in players {
            if appendEntitySprite(
                player.entityID,
                visibleWithin: bounds,
                to: &context,
                sprite: { entity in
                    player.sprite(for: entity)
                }
            ) {
                visibleEntityCount += 1
            }
        }

        return visibleEntityCount
    }

    private func appendPickupSprites(
        visibleWithin bounds: Rect,
        to context: inout RenderContext
    ) -> Int {
        var visibleEntityCount = 0

        for pickup in pickups {
            if appendEntitySprite(
                pickup.entityID,
                visibleWithin: bounds,
                to: &context,
                sprite: { entity in
                    pickup.sprite(for: entity)
                }
            ) {
                visibleEntityCount += 1
            }
        }

        return visibleEntityCount
    }

    private func appendEntitySprite(
        _ entityID: Entity.ID,
        visibleWithin bounds: Rect,
        to context: inout RenderContext,
        sprite: (Entity) -> Sprite
    ) -> Bool {
        guard let entity = entities[entityID],
              entity.bounds.intersects(bounds) else {
            return false
        }

        context.sprite(sprite(entity), layer: .entity)
        return true
    }

    private func appendColliderDebug(
        visibleWithin bounds: Rect,
        to context: inout RenderContext
    ) {
        let color = Color.green.opacity(0.35)

        level.tilemap.colliderIndex.forEach(intersecting: bounds) { collider in
            context.fill(collider.bounds, color: color, layer: .debug)
        }

        for player in players {
            guard let entity = entities[player.entityID],
                  let colliderBounds = entity.colliderWorldBounds,
                  colliderBounds.intersects(bounds) else {
                continue
            }

            context.fill(colliderBounds, color: color, layer: .debug)
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
