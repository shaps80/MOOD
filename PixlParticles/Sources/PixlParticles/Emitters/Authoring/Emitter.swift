import PixlRenderer
import Swift

public struct Emitter: Equatable, Sendable {
    public var spawnRegion: SpawnRegion
    public var spawnRate: Property<Float>
    public var lifetime: Property<Float>
    public var position: Property<Vec3>
    public var velocity: Property<Vec3>
    public var color: Property<Color>
    public var size: Property<Vec2>
    public var rotation: Property<Float>
    public var renderers: [ParticleRenderer]

    public init(
        spawnRegion: SpawnRegion,
        spawnRate: Property<Float> = .init(),
        lifetime: Property<Float> = .init(),
        position: Property<Vec3> = .init(),
        velocity: Property<Vec3> = .init(),
        color: Property<Color> = .init(),
        size: Property<Vec2> = .init(),
        rotation: Property<Float> = .init(),
        renderers: [ParticleRenderer] = [.init()]
    ) {
        spawnRegion.validate()

        self.spawnRegion = spawnRegion
        self.spawnRate = spawnRate
        self.lifetime = lifetime
        self.position = position
        self.velocity = velocity
        self.color = color
        self.size = size
        self.rotation = rotation
        self.renderers = renderers
    }

    public subscript<Value>(
        _ keyPath: WritableKeyPath<Self, Property<Value>>
    ) -> Property<Value>
    where Value: Codable & Equatable & Sendable {
        get { self[keyPath: keyPath] }
        set { self[keyPath: keyPath] = newValue }
    }
}
