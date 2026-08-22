import PixlRenderer
import Swift

public struct Emitter: Equatable, Sendable {
    public var capacity: Int
    public var spawnRegion: SpawnRegion
    public var position: Property<Vec3>
    public var velocity: Property<Vec3>
    public var color: Property<Color>
    public var size: Property<Vec2>
    public var rotation: Property<Float>
    public var renderers: [ParticleRenderer]

    public init(
        capacity: Int,
        spawnRegion: SpawnRegion,
        position: Property<Vec3> = .init(),
        velocity: Property<Vec3> = .init(),
        color: Property<Color> = .init(),
        size: Property<Vec2> = .init(),
        rotation: Property<Float> = .init(),
        renderers: [ParticleRenderer] = [.init()]
    ) {
        precondition(capacity >= 0)
        spawnRegion.validate()

        self.capacity = capacity
        self.spawnRegion = spawnRegion
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
