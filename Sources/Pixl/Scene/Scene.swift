import Swift

public protocol Scene {
    var assets: SceneAssets { get }
}

public struct World: Scene {
    public var level: Level
    public var camera: CameraRig?
    public var assets: SceneAssets { level.assets }
    internal private(set) var registry: EntityRegistry = .init()
    internal private(set) var phases: [Game.Phase] = [.update, .postCollision]
    internal private(set) var systems: [RegisteredSystem] = []

    public init(level: Level, camera: CameraRig? = nil) {
        self.level = level
        self.camera = camera
    }

    public mutating func register(_ entities: Entity.Type...) {
        entities.forEach {
            registry.register($0)
        }
    }

    /// Registers a custom system phase before an existing phase.
    ///
    /// Duplicate phases are ignored. In debug builds, duplicate or unknown phase
    /// registrations trigger an assertion failure; all builds print the problem
    /// to the console.
    public mutating func register(
        phase: Game.Phase,
        before existingPhase: Game.Phase
    ) {
        insertPhase(phase, relativeTo: existingPhase, offset: 0)
    }

    /// Registers a custom system phase after an existing phase.
    ///
    /// Duplicate phases are ignored. In debug builds, duplicate or unknown phase
    /// registrations trigger an assertion failure; all builds print the problem
    /// to the console.
    public mutating func register(
        phase: Game.Phase,
        after existingPhase: Game.Phase
    ) {
        insertPhase(phase, relativeTo: existingPhase, offset: 1)
    }

    /// Registers a system in the normal update phase.
    public mutating func addSystem(_ system: any GameSystem) {
        addSystem(system, phase: .update)
    }

    /// Registers a system in a specific phase.
    ///
    /// Systems in the same phase run in registration order. If `phase` is not
    /// registered, Pixl reports the problem and falls back to `.update`.
    public mutating func addSystem(
        _ system: any GameSystem,
        phase: Game.Phase
    ) {
        let phase = resolvedSystemPhase(phase)
        let exists = systems.contains { $0.phase == phase && type(of: $0.system) == type(of: system) }
        guard !exists else {
            reportPhaseIssue("Duplicate system for phase '\(phase.rawValue)'. Ignoring.")
            return
        }
        systems.append(RegisteredSystem(system: system, phase: phase))
    }

    /// Registers a system in a specific phase.
    ///
    /// This mirrors the phase registration wording for game code that prefers:
    ///
    /// ```swift
    /// world.register(system: AISystem(), phase: .ai)
    /// ```
    public mutating func register(
        system: any GameSystem,
        phase: Game.Phase = .update
    ) {
        addSystem(system, phase: phase)
    }

    private mutating func insertPhase(
        _ phase: Game.Phase,
        relativeTo existingPhase: Game.Phase,
        offset: Int
    ) {
        guard !phases.contains(phase) else {
            reportPhaseIssue("Game phase '\(phase.rawValue)' is already registered.")
            return
        }

        guard let existingIndex = phases.firstIndex(of: existingPhase) else {
            reportPhaseIssue("Cannot register phase '\(phase.rawValue)' relative to unknown phase '\(existingPhase.rawValue)'.")
            return
        }

        phases.insert(phase, at: existingIndex + offset)
    }

    private func resolvedSystemPhase(_ phase: Game.Phase) -> Game.Phase {
        guard phases.contains(phase) else {
            reportPhaseIssue("Cannot register system for unknown phase '\(phase.rawValue)'. Falling back to 'update'.")
            return .update
        }

        return phase
    }

    private func reportPhaseIssue(_ message: String) {
        assertionFailure(message)
        print("Pixl: \(message)")
    }
}

public struct Level {
    public let assets: SceneAssets
    public let tilemap: Tilemap?
    public let markers: [SpawnMarker]

    public init(
        assets: SceneAssets,
        tilemap: Tilemap? = nil,
        markers: [SpawnMarker] = []
    ) {
        self.assets = assets
        self.tilemap = tilemap
        self.markers = markers
    }
}
