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
    private var frameContext = RenderContext()
    public var renderCommands: [RenderCommand] { renderContext.commands }
    public private(set) var renderBatches: [RenderBatch] = []
    public private(set) var renderStats = RenderStats()

    public init(
        size: Vec2 ,
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
            var entity = spawn.entity

            var state = EntityState(id: spawn.id)

            state.move(to: spawn.position, velocity: .zero)

            var context = PreparationContext(level: level)
            entity.prepare(context: &context, state: &state)
            state.finalizePreparation()

            entityRecords.append(EntityRecord(id: spawn.id, entity: entity))
            entityStates.insert(state)
        }
        updateCamera(delta: .infinity)
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
        frameContext.removeAll(keepingCapacity: true)
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
            appendFrameCommands(from: entityContext)
        }

        context.detectContacts()
        contacts.endFrame()
        dispatchCollisions(context: context, sounds: &frameSounds)

        updateCamera(delta: delta)
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
            appendFrameCommands(from: entityContext)
        }
    }

    private mutating func appendFrameCommands(from context: Context) {
        frameContext.append(contentsOf: context.renderContext.commands)
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
        renderContext.append(contentsOf: frameContext.commands)

        if debugOptions.contains(.colliders) {
            appendColliderDebug(visibleWithin: visibleBounds, to: &renderContext)
        }

        if debugOptions.contains(.visibility) {
            renderContext.stroke(
                visibleBounds,
                color: Color(red: 0, green: 0.8, blue: 1, alpha: 0.5),
                width: 2,
                layer: 900
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

                context.draw(
                    Sprite(
                        material: tile.material,
                        layer: tile.layer,
                        blendMode: tile.blendMode,
                        tint: tile.tint
                    ),
                    at: Vec2(
                            x: (Double(x) * level.tilemap.tileSize.x)
                                + (level.tilemap.tileSize.x / 2),
                            y: (Double(y) * level.tilemap.tileSize.y)
                                + (level.tilemap.tileSize.y / 2)
                    )
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
                  let sprite = state.sprite
            else {
                continue
            }

            context.draw(sprite, at: state.position)
            visibleEntityCount += 1
        }

        return visibleEntityCount
    }

    private func appendColliderDebug(
        visibleWithin bounds: Rect,
        to context: inout RenderContext
    ) {
        let style = RenderStyle(
            fill: Color.green.opacity(0.25),
            blendMode: .normal
        )

        level.tilemap.colliderIndex.forEach(intersecting: bounds) { collider in
            context.draw(collider.shape, in: collider.bounds, style: style, layer: 900)
        }

        for record in entityRecords {
            guard let state = entityStates[record.id] else {
                continue
            }

            for collider in state.worldColliders where collider.bounds.intersects(bounds) {
                context.draw(collider.shape, in: collider.bounds, style: style, layer: 900)
            }
        }
    }

    private mutating func updateCamera(delta: Double) {
        cameraRig.update(delta: delta, anchorBounds: entityBounds)
    }

    private func entityBounds(for id: EntityID) -> Rect? {
        entityStates.bounds(for: id)
    }
}

extension Game {
    public struct PreparationContext {
        public let level: Level

        init(level: Level) {
            self.level = level
        }
    }

    public struct Context {
        public let delta: Double
        public let input: Input
        public let level: Level
        let contacts: ContactState
        private let collisionSystem: CollisionSystem
        fileprivate private(set) var sounds: [SoundID] = []
        fileprivate private(set) var renderContext = RenderContext()

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

        public mutating func draw(_ sprite: Sprite, at position: Vec2) {
            renderContext.draw(sprite, at: position)
        }

        public mutating func draw(
            _ path: Path,
            style: RenderStyle = RenderStyle(),
            layer: RenderLayer = 0
        ) {
            renderContext.draw(path, style: style, layer: layer)
        }

        public mutating func draw<S: Shape>(
            _ shape: S,
            in rect: Rect,
            style: RenderStyle = RenderStyle(),
            layer: RenderLayer = 0
        ) {
            renderContext.draw(shape, in: rect, style: style, layer: layer)
        }

        public func move(state: inout EntityState, velocity: Vec2) {
            collisionSystem.move(state: &state, velocity: velocity)
        }

        func detectContacts() {
            collisionSystem.detectContacts(into: contacts)
        }
    }
}
