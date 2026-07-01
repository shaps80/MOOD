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

    private let level: OldLevel
    private var entityStates: EntityStore = .init()
    private let contacts = ContactState()
    private var cameraRig: CameraRig
    private var wasResetPressed = false
    private var wasDebugTogglePressed = false
    private var debugOptions: DebugOptions = []

    public let soundAssets: [SoundAsset]
    public let spriteAssets: [SpriteAsset]

    private var frame = Frame()
    private(set) var renderBatches: [RenderBatch] = []
    private(set) var renderStats = RenderStats()

    public init(
        size: Vec2,
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 60,
        world: World
    ) {
        self.logicalResolution = size
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.cameraRig = world.camera ?? .init(
            camera: .init(viewportSize: size),
            anchor: .entities([]),
        )

        self.spriteAssets = world.assets.sprites
        self.soundAssets = world.assets.sounds

        if let tilemap = world.level.tilemap {
            self.level = .init(
                tilemap: tilemap,
                spawnPoint: .init(
                    x: 32,
                    y: 32
                )
            )
        } else {
            self.level = .init(
                tilemap: .init(
                    columns: 20,
                    rows: 10,
                    tileSize: .init(x: 16, y: 16),
                    fill: .empty
                ),
                spawnPoint: .init(x: 16, y: 16)
            )
        }

        var id: Int = 0
        for marker in world.level.markers {
            guard var entity = world.registry.make(kind: marker.kind) else { continue }
            defer { id += 1 }

            var state = EntityState(id: .init(rawValue: id))
            state.position = marker.position
            state.velocity = .zero

            var context = PreparationContext(level: level)
            entity.prepare(context: &context, state: &state)

            entityStates.insert(entity: entity, state: state)
        }

        updateCamera(delta: .infinity)
        frame.prepare()
        rebuildFrame()
    }

    public init(
        size: Vec2 ,
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 60,
        level: OldLevel,
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

            state.position = spawn.position
            state.velocity = .zero

            var context = PreparationContext(level: level)
            entity.prepare(context: &context, state: &state)

            entityStates.insert(entity: entity, state: state)
        }
        updateCamera(delta: .infinity)
        frame.prepare()
        rebuildFrame()
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

        frame.prepare()
        contacts.begin()

        var context = Context(
            delta: delta,
            input: input,
            level: level,
            contacts: contacts
        )

        entityStates.updateEach { entity, state in
                entity.onUpdate(context: &context, state: &state)
        }

        let collisionSystem = CollisionSystem(
            tilemap: level.tilemap,
            entities: entityStates,
            delta: delta
        )
        entityStates.applyMovement(collisionSystem: collisionSystem)
        collisionSystem.detectContacts(into: contacts)
        contacts.end()
        dispatchCollisions(context: &context)

        updateCamera(delta: delta)
        frame.sounds.append(contentsOf: context.sounds)
        rebuildFrame()
    }

    private mutating func dispatchCollisions(
        context: inout Context
    ) {
        entityStates.updateEachWithContacts(contacts: contacts) { entity, state, contact in
            entity.onCollision(
                context: &context,
                state: &state,
                contact: contact
            )
        }
    }

    public mutating func drainSounds() -> [SoundID] {
        defer {
            frame.sounds.removeAll(keepingCapacity: true)
        }

        return frame.sounds
    }

    private mutating func rebuildFrame() {
        let visibleBounds = renderView.visibleBounds
        var visibleTileCount = 0
        var visibleEntityCount = 0

        visibleTileCount += appendTileSprites(visibleWithin: visibleBounds)
        visibleEntityCount += appendEntitySprites(visibleWithin: visibleBounds)

        if debugOptions.contains(.colliders) {
            appendColliderDebug(visibleWithin: visibleBounds)
        }

        if debugOptions.contains(.visibility) {
            appendStroke(
                visibleBounds,
                color: Color(red: 0, green: 0.8, blue: 1, alpha: 0.5),
                width: 2,
                layer: 900
            )
        }

        sortFrameCommands()
        renderBatches = RenderBatch.make(from: frame.commands)
        renderStats = RenderStats(
            commandCount: frame.commands.count,
            primitiveCount: frame.commands.reduce(into: 0) { count, command in
                count += command.primitiveCount
            },
            batchCount: renderBatches.count,
            visibleTileCount: visibleTileCount,
            visibleEntityCount: visibleEntityCount
        )
    }

    private mutating func appendTileSprites(
        visibleWithin bounds: Rect
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

                appendSprite(
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

    private mutating func appendEntitySprites(
        visibleWithin bounds: Rect
    ) -> Int {
        var visibleEntityCount = 0

        entityStates.forEachState { state in
            guard state.bounds.intersects(bounds),
                  let sprite = state.sprite
            else { return }

            appendSprite(sprite, at: state.position)
            visibleEntityCount += 1
        }

        return visibleEntityCount
    }

    private mutating func appendColliderDebug(
        visibleWithin bounds: Rect
    ) {
        let style = RenderStyle(
            fill: Color.green.opacity(0.25),
            blendMode: .normal
        )

        level.tilemap.colliderIndex.forEach(intersecting: bounds) { collider in
            appendShape(collider.shape, in: collider.bounds, style: style, layer: 900)
        }

        entityStates.forEachState { state in
            for collider in state.worldColliders where collider.bounds.intersects(bounds) {
                appendShape(collider.shape, in: collider.bounds, style: style, layer: 900)
            }
        }
    }

    private mutating func appendSprite(_ sprite: Sprite, at position: Vec2) {
        frame.commands.append(
            .sprite(PositionedSprite(sprite: sprite, position: position))
        )
    }

    private mutating func appendShape<S: Shape>(
        _ shape: S,
        in rect: Rect,
        style: RenderStyle,
        layer: RenderLayer
    ) {
        appendPath(shape.path(in: rect), style: style, layer: layer)
    }

    private mutating func appendPath(
        _ path: Path,
        style: RenderStyle,
        layer: RenderLayer
    ) {
        frame.commands.append(.path(path.applying(style, layer: layer)))
    }

    private mutating func appendStroke(
        _ rect: Rect,
        color: Color,
        width: Double,
        layer: RenderLayer
    ) {
        appendPath(
            Path(rect),
            style: RenderStyle(
                fill: nil,
                stroke: color,
                strokeStyle: StrokeStyle(lineWidth: width)
            ),
            layer: layer
        )
    }

    private mutating func sortFrameCommands() {
        frame.commands = frame.commands.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.layer != rhs.element.layer {
                    return lhs.element.layer < rhs.element.layer
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
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
        public let level: OldLevel

        init(level: OldLevel) {
            self.level = level
        }
    }

    public struct Context {
        public let delta: Double
        public let input: Input
        public let level: OldLevel
        let contacts: ContactState
        fileprivate private(set) var sounds: [SoundID] = []

        init(
            delta: Double,
            input: Input,
            level: OldLevel,
            contacts: ContactState
        ) {
            self.delta = max(delta, 0)
            self.input = input
            self.level = level
            self.contacts = contacts
        }

        public mutating func play(sound: SoundID) {
            sounds.append(sound)
        }

    }
}
