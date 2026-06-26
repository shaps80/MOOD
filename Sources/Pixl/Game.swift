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

    private var sounds: [SoundID] = []
    public let soundAssets: [SoundAsset]
    public let spriteAssets: [SpriteAsset]

    private var renderContext = RenderContext()
    public var renderCommands: [RenderCommand] { renderContext.commands }
    public private(set) var renderBatches: [RenderBatch] = []
    public private(set) var renderStats = RenderStats()

    public init(
        size: Vec2 = .init(x: 800, y: 400),
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 60,
        level: Level,
        camera: CameraRig,
        entities: [EntitySpawn],
        sprites: [SpriteAsset],
        sounds: [SoundAsset]
    ) {
        self.logicalResolution = size
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.level = level
        self.cameraRig = camera
        self.spriteAssets = sprites
        self.soundAssets = sounds

        for spawn in entities {
            entityRecords.append(EntityRecord(id: spawn.id, entity: spawn.entity))

            var state = EntityState(
                id: spawn.id,
                size: spawn.entity.size,
                colliders: spawn.entity.colliders
            )

            state.move(to: spawn.position, velocity: .zero)
            entityStates.insert(state)
        }

        updateCamera()
        rebuildSpriteBuffer()
    }

    public mutating func update(delta: Double, input: Input) {
        defer {
            wasResetPressed = input.reset
            wasDebugTogglePressed = input.jump
        }

        if input.jump && !wasDebugTogglePressed {
            debugOptions.toggle(.visibility)
            debugOptions.toggle(.colliders)
        }

        var frameSounds: [SoundID] = []
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
        sounds: inout [SoundID]
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

    public mutating func drainSounds() -> [SoundID] {
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

    private mutating func updateCamera() {
        cameraRig.update(anchorBounds: entityBounds)
    }

    private func entityBounds(for id: EntityID) -> Rect? {
        entityStates.bounds(for: id)
    }
}

extension Game {
    public struct Context {
        public let delta: Double
        public let input: Input
        public let level: Level
        let contacts: ContactState
        private let collisionSystem: CollisionSystem
        fileprivate private(set) var sounds: [SoundID] = []

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

        public mutating func play(sound: SoundID) {
            sounds.append(sound)
        }

        public func move(state: inout EntityState, velocity: Vec2) {
            collisionSystem.move(state: &state, velocity: velocity)
        }

        func detectContacts() {
            collisionSystem.detectContacts(into: contacts)
        }
    }
}
