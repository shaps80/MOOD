import PixlRenderer
import Swift

struct CompiledEmitter: Equatable, Sendable {
    struct SpawnRate: Equatable, Sendable {
        let whole: UInt32
        let remainder: UInt64
        let denominator: UInt64
    }

    enum Velocity: Equatable, Sendable {
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
    }

    struct Constants: Equatable, Sendable {
        let spawnRegion: SpawnRegion
        let spawnRate: SpawnRate
        let lifetimeTicks: UInt32
        let velocity: Velocity
        let color: Color
        let size: Vec2
        let rotation: Float
    }

    let storage: EmitterStorageLayout
    let constants: Constants
    let passes: [EmitterPass]
    let renderers: [ParticleRenderer]
}
