import Observation
import PixlParticles

/// One document-owned simulation. Views never retain an initial System value.
@MainActor
@Observable
final class ParticleSimulation {
    private(set) var system: System
    private(set) var revision: UInt64 = 0
    @ObservationIgnored private var configuration: ParticleSimulationConfiguration

    init(snapshot: ParticleDocument.Snapshot) {
        configuration = .init(snapshot)
        system = Self.makeSystem(snapshot)
    }

    func update(with snapshot: ParticleDocument.Snapshot) {
        let next = ParticleSimulationConfiguration(snapshot)
        guard next != configuration else { return }
        configuration = next
        system = Self.makeSystem(snapshot)
        revision &+= 1
    }

    private static func makeSystem(_ snapshot: ParticleDocument.Snapshot) -> System {
        System(
            seed: UInt64(snapshot.seed),
            emitter: EmitterPreset.debris.emitter().applying(snapshot),
            duration: .seconds(snapshot.duration),
            storesRewindState: false
        )
    }
}
