import PixlRenderer
import Swift

struct CompiledEmitter: Equatable, Sendable {
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
