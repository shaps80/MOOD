import Swift

public protocol Scene {
    var assets: SceneAssets { get }
}

public struct World: Scene {
    public let level: Level
    public let camera: CameraRig?
    public var assets: SceneAssets { level.assets }
    internal private(set) var registry: EntityRegistry = .init()

    public init(level: Level, camera: CameraRig? = nil) {
        self.level = level
        self.camera = camera
    }

    public mutating func register(_ entities: Entity.Type...) {
        entities.forEach {
            registry.register($0)
        }
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
