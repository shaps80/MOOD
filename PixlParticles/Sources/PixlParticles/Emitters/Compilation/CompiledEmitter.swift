import PixlRenderer
import Swift

struct CompiledEmitter: Equatable, Sendable {
    struct Constants: Equatable, Sendable {
        let position: SpawnRegion
        let velocity: Emitter.Velocity
        let color: Color
        let size: Vec2
        let rotation: Float
    }

    let storage: EmitterStorageLayout
    let constants: Constants
    let passes: [EmitterPass]
    let renderers: [ParticleRenderer]
}
