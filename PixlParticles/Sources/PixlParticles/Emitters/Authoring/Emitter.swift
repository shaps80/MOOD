import PixlRenderer
import Swift

public struct Emitter: Equatable, Sendable {
    public enum Velocity: Equatable, Sendable {
        case stationary
        case random(Range<Float>)

        var requiresStorage: Bool {
            switch self {
            case .stationary:
                false
            case let .random(range):
                range.lowerBound != 0 || range.upperBound != 0
            }
        }

        func validate() {
            switch self {
            case .stationary:
                break
            case let .random(range):
                precondition(
                    range.lowerBound.isFinite && range.upperBound.isFinite
                )
            }
        }
    }

    public var capacity: Int
    public var position: SpawnRegion
    public var velocity: Velocity
    public var color: Color
    public var size: SIMD2<Float>
    public var rotation: Float
    public var renderers: [ParticleRenderer]

    public init(
        capacity: Int,
        position: SpawnRegion,
        velocity: Velocity = .random(-20 ..< 20),
        color: Color = .white,
        size: SIMD2<Float> = [1, 2],
        rotation: Float = 0,
        renderers: [ParticleRenderer] = [.init()]
    ) {
        precondition(capacity >= 0)
        precondition(size.x.isFinite && size.y.isFinite)
        precondition(size.x >= 0 && size.y >= 0)
        precondition(rotation.isFinite)
        position.validate()
        velocity.validate()

        self.capacity = capacity
        self.position = position
        self.velocity = velocity
        self.color = color
        self.size = size
        self.rotation = rotation
        self.renderers = renderers
    }
}
