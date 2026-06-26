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
    private var entityRecords: [EntityRecord] = []
    private var entityStates: EntityStore = .init()
    private let contacts = ContactState()
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

        self.cameraRig = CameraRig(
            camera: Camera(viewportSize: logicalResolution),
            anchor: .entities([.player]),
            constraints: CameraConstraints(bounds: level.bounds)
        )

        self.entityRecords = [
            EntityRecord(id: .enemy, entity: Enemy()),
            EntityRecord(id: .player, entity: Player()),
            EntityRecord(id: .pickup, entity: Pickup()),
        ]

        insertInitialEntityStates()

        updateCamera()
        rebuildSpriteBuffer()
    }

    private mutating func insertInitialEntityStates() {
        for record in entityRecords {
            var state = EntityState(
                id: record.id,
                size: record.entity.size,
                colliders: record.entity.colliders
            )

            placeInitialState(&state, for: record.id)
            entityStates.insert(state)
        }
    }

    private func placeInitialState(_ state: inout EntityState, for id: EntityID) {
        let center: Vec2

        if id == .player {
            center = level.spawnPoint
        } else if id == .pickup {
            center = Vec2(
                x: level.spawnPoint.x + (level.tilemap.tileSize.x * 8),
                y: level.spawnPoint.y
            )
        } else if id == .enemy {
            center = .init(x: 64, y: 64)
        } else {
            center = .zero
        }

        state.move(
            to: Vec2(
                x: center.x - (state.size.x / 2),
                y: center.y - (state.size.y / 2)
            ),
            velocity: .zero
        )
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

        var frameSounds: [Sound] = []
        contacts.beginFrame()

        let context = Context(
            delta: delta,
            input: input,
            level: level,
            entities: entityStates,
            contacts: contacts
        )

        for index in entityRecords.indices {
            let entityID = entityRecords[index].id
            var entityContext = context
            var entity = entityRecords[index].entity

            entityStates.update(entityID) { state in
                entity.onUpdate(context: &entityContext, state: &state)
            }

            entityRecords[index].entity = entity
            frameSounds.append(contentsOf: entityContext.sounds)
        }

        context.detectContacts()
        contacts.endFrame()
        dispatchCollisions(context: context, sounds: &frameSounds)

        updateCamera()
        sounds.append(contentsOf: frameSounds)
        rebuildSpriteBuffer()
    }

    private mutating func dispatchCollisions(
        context: Context,
        sounds: inout [Sound]
    ) {
        for index in entityRecords.indices {
            let entityID = entityRecords[index].id
            var entityContext = context
            var entity = entityRecords[index].entity

            for contact in contacts[entityID] {
                entityStates.update(entityID) { state in
                    entity.onCollision(
                        context: &entityContext,
                        state: &state,
                        contact: contact
                    )
                }
            }

            entityRecords[index].entity = entity
            sounds.append(contentsOf: entityContext.sounds)
        }
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
        visibleEntityCount += appendEntitySprites(visibleWithin: visibleBounds, to: &renderContext)

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

    private func appendEntitySprites(
        visibleWithin bounds: Rect,
        to context: inout RenderContext
    ) -> Int {
        var visibleEntityCount = 0

        for record in entityRecords {
            guard let state = entityStates[record.id],
                  state.bounds.intersects(bounds),
                  let sprite = record.entity.sprite(for: state)
            else {
                continue
            }

            context.sprite(sprite, layer: .entity)
            visibleEntityCount += 1
        }

        return visibleEntityCount
    }

    private func appendColliderDebug(
        visibleWithin bounds: Rect,
        to context: inout RenderContext
    ) {
        let color = Color.green.opacity(0.35)

        level.tilemap.colliderIndex.forEach(intersecting: bounds) { collider in
            context.fill(collider.bounds, color: color, layer: .debug)
        }

        for record in entityRecords {
            guard let state = entityStates[record.id] else {
                continue
            }

            for frame in state.colliderFrames where frame.intersects(bounds) {
                context.fill(frame, color: color, layer: .debug)
            }
        }
    }

    private mutating func resetPlayers() {
        entityStates.update(.player) { state in
            placeInitialState(&state, for: .player)
        }
    }

    private mutating func updateCamera() {
        cameraRig.update(anchorBounds: entityBounds)
    }

    private func entityBounds(for id: EntityID) -> Rect? {
        entityStates.bounds(for: id)
    }
}

extension Game {
    struct Context {
        let delta: Double
        let input: Input
        let level: Level
        let contacts: ContactState
        private let collisionSystem: CollisionSystem
        fileprivate private(set) var sounds: [Sound] = []

        init(
            delta: Double,
            input: Input,
            level: Level,
            entities: EntityStore,
            contacts: ContactState
        ) {
            self.delta = max(delta, 0)
            self.input = input
            self.level = level
            self.contacts = contacts
            self.collisionSystem = CollisionSystem(
                tilemap: level.tilemap,
                entities: entities,
                delta: delta
            )
        }

        mutating func play(sound: Sound) {
            sounds.append(sound)
        }

        func move(state: inout EntityState, velocity: Vec2) {
            collisionSystem.move(state: &state, velocity: velocity)
        }

        func detectContacts() {
            collisionSystem.detectContacts(into: contacts)
        }
    }
}
