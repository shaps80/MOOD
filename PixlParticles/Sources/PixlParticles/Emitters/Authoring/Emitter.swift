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
        velocity: Property<Vec3> = .init([
            .set(
                .random(
                    from: [-20, -20, -20],
                    to: [20, 20, 20],
                    variation: .perValue
                )
            ),
        ]),
        color: Property<Color> = .init([.set(.white)]),
        size: Property<Vec2> = .init([.set([1, 2])]),
        rotation: Property<Float> = .init([.set(0)]),
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
