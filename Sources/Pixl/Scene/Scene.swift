import Swift

public protocol Scene {
    var assets: SceneAssets { get }
}

public struct World: Scene {
    public let level: Level
    public var assets: SceneAssets { level.assets }
}

public struct Level {
    public let assets: SceneAssets
    public let tilemap: Tilemap?
    public let markers: [SpawnMarker]
}
