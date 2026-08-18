import PixlRenderer
import Swift

public struct Emitter: Equatable, Sendable {
    public var capacity: Int
    public var spawnRegion: SpawnRegion
    public var position: Property<Vec3>
    public var velocity: Property<Vec3>
    public var color: Property<Color>
    public var size: Vec2
    public var rotation: Float
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
        size: Vec2 = [1, 2],
        rotation: Float = 0,
        renderers: [ParticleRenderer] = [.init()]
    ) {
        precondition(capacity >= 0)
        precondition(size.x.isFinite && size.y.isFinite)
        precondition(size.x >= 0 && size.y >= 0)
        precondition(rotation.isFinite)
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
