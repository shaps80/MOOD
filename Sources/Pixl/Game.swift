import Swift

public struct Game {
    public let title: String
    public let logicalResolution: Vec2
    public let interpolationMode: InterpolationMode
    public let preferredFps: Double
    public var timeScale: Double {
        didSet {
            timeScale = Self.clampedTimeScale(timeScale)
        }
    }
    public private(set) var clearColor: Color = .white
    public var camera: Camera { cameraRig.camera }
    var cameraTransform: Transform { cameraRig.resolvedTransform }
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
    private let initialEntitySource: InitialEntitySource
    private let phases: [Phase]
    private let initialSystems: [RegisteredSystem]
    private var entityStates: EntityStore = .init()
    private var systems: [RegisteredSystem]
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
        _ title: String,
        size: Vec2,
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 60,
        timeScale: Double = 1,
        world: World
    ) {
        self.title = title
        self.logicalResolution = size
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.timeScale = Self.clampedTimeScale(timeScale)
        self.cameraRig = world.camera ?? .init(
            camera: .init(viewportSize: size),
            anchor: .entities([]),
        )

        self.spriteAssets = world.assets.sprites
        self.soundAssets = world.assets.sounds
        self.initialEntitySource = .markers(world.level.markers, world.registry)
        self.phases = world.phases
        self.initialSystems = world.systems
        self.systems = world.systems

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

        loadInitialEntities()
        updateCamera(delta: .infinity)
        frame.prepare()
        rebuildFrame()
    }

    public init(
        _ title: String,
        size: Vec2 ,
        interpolationMode: InterpolationMode = .nearest,
        preferredFPS: Double = 60,
        timeScale: Double = 1,
        level: OldLevel,
        camera: CameraRig,
        entities: [EntitySpawn],
        sprites: [SpriteAsset],
        sounds: [SoundAsset]
    ) {
        self.title = title
        self.logicalResolution = size
        self.interpolationMode = interpolationMode
        self.preferredFps = preferredFPS
        self.timeScale = Self.clampedTimeScale(timeScale)
        self.level = level
        self.cameraRig = camera
        self.spriteAssets = sprites
        self.soundAssets = sounds
        self.initialEntitySource = .spawns(entities)
        self.phases = [.update, .postCollision]
        self.initialSystems = []
        self.systems = []

        loadInitialEntities()
        updateCamera(delta: .infinity)
        frame.prepare()
        rebuildFrame()
    }

    public mutating func update(delta: Double, input: Input) {
        defer {
            wasResetPressed = input.reset
            wasDebugTogglePressed = input.debug
        }

        if input.debug && !wasDebugTogglePressed {
            debugOptions.toggle(.visibility)
            debugOptions.toggle(.colliders)
        }

        if let requestedTimeScale = input.timeScale {
            timeScale = requestedTimeScale
        }

        let simulationDelta = delta * timeScale

        frame.prepare()
        contacts.begin()

        var context = Context(
            delta: simulationDelta,
            input: input,
            level: level,
            contacts: contacts,
            camera: cameraRig
        )

        entityStates.updateEach { entity, state in
                entity.onUpdate(context: &context, state: &state)
        }

        var systemContext = SystemContext(
            delta: context.delta,
            level: level,
            entityStates: entityStates,
            camera: context.camera
        )
        updateSystems(before: .postCollision, context: &systemContext)
        context.camera = systemContext.camera
        if systemContext.shouldRestart {
            context.restart()
        }

        let collisionSystem = CollisionSystem(
            tilemap: level.tilemap,
            entities: entityStates,
            delta: simulationDelta
        )
        entityStates.applyMovement(collisionSystem: collisionSystem)
        collisionSystem.detectContacts(into: contacts)
        contacts.end()
        dispatchCollisions(context: &context)

        systemContext = SystemContext(
            delta: context.delta,
            level: level,
            entityStates: entityStates,
            camera: context.camera
        )
        updateSystems(from: .postCollision, context: &systemContext)
        context.camera = systemContext.camera
        if systemContext.shouldRestart {
            context.restart()
        }

        cameraRig = context.camera
        flushFrameEvents(from: &context)

        updateCamera(delta: simulationDelta)
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

    private mutating func updateSystems(
        before boundary: Phase,
        context: inout SystemContext
    ) {
        for phase in phases {
            guard phase != boundary else { return }
            updateSystems(in: phase, context: &context)
        }
    }

    private mutating func updateSystems(
        from boundary: Phase,
        context: inout SystemContext
    ) {
        guard let boundaryIndex = phases.firstIndex(of: boundary) else {
            return
        }

        for phase in phases[boundaryIndex...] {
            updateSystems(in: phase, context: &context)
        }
    }

    private mutating func updateSystems(
        in phase: Phase,
        context: inout SystemContext
    ) {
        for index in systems.indices where systems[index].phase == phase {
            systems[index].system.update(context: &context)
        }
    }

    public mutating func drainSounds() -> [SoundID] {
        frame.drainSounds()
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
                    in: Transform(
                        position: Vec2(
                            x: (Double(x) * level.tilemap.tileSize.x)
                                + (level.tilemap.tileSize.x / 2),
                            y: (Double(y) * level.tilemap.tileSize.y)
                                + (level.tilemap.tileSize.y / 2)
                        )
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

            appendSprite(sprite, in: state.transform)
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
            appendShape(collider.shape, in: collider.shapeFrame, rotation: collider.rotation, style: style, layer: 900)
        }

        entityStates.forEachState { state in
            for collider in state.worldColliders where collider.bounds.intersects(bounds) {
                appendShape(collider.shape, in: collider.shapeFrame, rotation: collider.rotation, style: style, layer: 900)
            }
        }
    }

    private mutating func appendSprite(_ sprite: Sprite, in transform: Transform) {
        let worldTransform = transform.concatenated(with: sprite.transform)
        var sprite = sprite
        sprite.transform = Transform(scale: worldTransform.scale)

        frame.commands.append(
            .sprite(
                PositionedSprite(
                    sprite: sprite,
                    position: worldTransform.position,
                    rotation: worldTransform.rotation
                )
            )
        )
    }

    private mutating func appendShape<S: Shape>(
        _ shape: S,
        in rect: Rect,
        rotation: Angle = .zero,
        style: RenderStyle,
        layer: RenderLayer
    ) {
        var path = shape.path(in: rect)
        path.rotation = rotation
        appendPath(path, style: style, layer: layer)
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

    private mutating func flushFrameEvents(from context: inout Context) {
        frame.sounds.append(contentsOf: context.drainSounds())
        applyLifecycleCommands(context.drainLifecycleCommands())
    }

    private mutating func applyLifecycleCommands(_ commands: [LifecycleCommand]) {
        guard !commands.isEmpty else { return }

        if commands.containsRestart {
            restart()
            return
        }

        var despawned = Set<EntityID>()

        for command in commands {
            guard case .despawn(let id) = command,
                  despawned.insert(id).inserted
            else {
                continue
            }

            entityStates.remove(id)
        }

        for command in commands {
            guard case .spawn(let entityType, let position, let coordinateSpace) = command,
                  let worldPosition = resolve(position, in: coordinateSpace)
            else {
                continue
            }

            spawn(entityType, topLeft: worldPosition)
        }
    }

    private mutating func spawn(_ entityType: any Entity.Type, topLeft position: Vec2) {
        var entity = entityType.init()
        let id = entityStates.allocateID()
        var state = EntityState(id: id)
        state.velocity = .zero

        var context = PreparationContext(level: level)
        entity.prepare(context: &context, state: &state)
        state.moveTopLeft(to: position)

        entityStates.insert(entity: entity, state: state)
    }

    private mutating func restart() {
        entityStates = EntityStore()
        systems = initialSystems
        contacts.reset()
        loadInitialEntities()
    }

    private mutating func loadInitialEntities() {
        switch initialEntitySource {
        case .markers(let markers, let registry):
            var id: Int = 0
            for marker in markers {
                guard let entity = registry.make(kind: marker.kind) else { continue }
                defer { id += 1 }

                insertInitialEntity(
                    entity: entity,
                    id: EntityID(rawValue: id),
                    position: marker.position
                )
            }

        case .spawns(let spawns):
            for spawn in spawns {
                insertInitialEntity(
                    entity: spawn.entity,
                    id: spawn.id,
                    position: spawn.position
                )
            }
        }
    }

    private mutating func insertInitialEntity(
        entity: any Entity,
        id: EntityID,
        position: Vec2
    ) {
        var entity = entity
        var state = EntityState(id: id)
        state.transform.position = position
        state.velocity = .zero

        var context = PreparationContext(level: level)
        entity.prepare(context: &context, state: &state)

        entityStates.insert(entity: entity, state: state)
    }

    private func resolve(_ position: Vec2, in coordinateSpace: CoordinateSpace) -> Vec2? {
        switch coordinateSpace {
        case .world:
            return position

        case .screen:
            return renderView.bounds.origin + position

        case .entity(let id):
            guard let state = entityStates[id] else {
                return nil
            }

            return state.convertToWorld(position)
        }
    }
}

private extension Game {
    static func clampedTimeScale(_ value: Double) -> Double {
        guard value.isFinite else {
            return 1
        }

        return max(value, .leastNonzeroMagnitude)
    }
}

private extension DebugOptions {
    var isEnabled: Bool {
        !isEmpty
    }
}

extension Game {
    private enum InitialEntitySource {
        case markers([SpawnMarker], EntityRegistry)
        case spawns([EntitySpawn])
    }

    enum LifecycleCommand {
        case spawn(any Entity.Type, Vec2, CoordinateSpace)
        case despawn(EntityID)
        case restart
    }

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
        public var camera: CameraRig
        let contacts: ContactState
        private var sounds: [SoundID] = []
        private var lifecycleCommands: [LifecycleCommand] = []

        init(
            delta: Double,
            input: Input,
            level: OldLevel,
            contacts: ContactState,
            camera: CameraRig
        ) {
            self.delta = max(delta, 0)
            self.input = input
            self.level = level
            self.contacts = contacts
            self.camera = camera
        }

        public mutating func play(sound: SoundID) {
            sounds.append(sound)
        }

        /// Queues an entity to be spawned after the current update or collision
        /// phase finishes.
        ///
        /// The position is resolved from the supplied coordinate space into a
        /// world-space top-left point for the spawned entity. Spawned entities
        /// receive a Pixl-assigned unique ID.
        ///
        /// ```swift
        /// context.spawn(Bullet.self, at: Vec2(x: 120, y: 40))
        /// context.spawn(Bullet.self, at: Vec2(x: 0, y: -24), in: .entity(playerID))
        /// ```
        public mutating func spawn<E: Entity>(
            _ entityType: E.Type,
            at position: Vec2,
            in coordinateSpace: CoordinateSpace = .world
        ) {
            lifecycleCommands.append(.spawn(entityType, position, coordinateSpace))
        }

        /// Queues an entity to be removed after the current update or collision
        /// phase finishes.
        ///
        /// Duplicate despawn requests for the same ID are ignored when the
        /// queued commands are applied.
        public mutating func despawn(_ id: EntityID) {
            lifecycleCommands.append(.despawn(id))
        }

        /// Queues the game to restart from its initial entities and systems.
        public mutating func restart() {
            lifecycleCommands.append(.restart)
        }

        mutating func drainSounds() -> [SoundID] {
            defer {
                sounds.removeAll(keepingCapacity: true)
            }

            return sounds
        }

        mutating func drainLifecycleCommands() -> [LifecycleCommand] {
            defer {
                lifecycleCommands.removeAll(keepingCapacity: true)
            }

            return lifecycleCommands
        }
    }

    public struct SystemContext {
        public let delta: Double
        public let level: OldLevel
        public var camera: CameraRig
        private let entityStates: EntityStore
        fileprivate private(set) var shouldRestart = false

        init(
            delta: Double,
            level: OldLevel,
            entityStates: EntityStore,
            camera: CameraRig
        ) {
            self.delta = max(delta, 0)
            self.level = level
            self.entityStates = entityStates
            self.camera = camera
        }

        public func ids<E: Entity>(kind: E.Type) -> [EntityID] {
            entityStates.ids(kind: kind.kind)
        }

        public func bounds(for id: EntityID) -> Rect? {
            entityStates.bounds(for: id)
        }

        public func bounds(for ids: [EntityID]) -> Rect? {
            var unionBounds: Rect?

            for id in ids {
                guard let bounds = entityStates.bounds(for: id) else {
                    continue
                }

                unionBounds = unionBounds.map { $0.union(bounds) } ?? bounds
            }

            return unionBounds
        }

        public func move(_ ids: [EntityID], by offset: Vec2) {
            for id in ids {
                entityStates.update(id) { state in
                    state.transform.position += offset
                }
            }
        }

        public mutating func restart() {
            shouldRestart = true
        }
    }
}

private extension Array where Element == Game.LifecycleCommand {
    var containsRestart: Bool {
        contains {
            guard case .restart = $0 else {
                return false
            }

            return true
        }
    }
}
