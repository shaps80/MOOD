import PixlParticles

/// Only authored inputs that require restarting simulation.
struct ParticleSimulationConfiguration: Equatable {
    let seed: UInt64
    let spawnRate: Float
    let lifetime: Float
    let region: SpawnRegion
    let color: PixlParticles.Color

    init(_ snapshot: ParticleDocument.Snapshot) {
        seed = UInt64(snapshot.seed)
        spawnRate = Float(snapshot.spawnRate)
        lifetime = Float(snapshot.lifetime)
        region = snapshot.spawnPreset.region(domain: snapshot.spawnDomain)
        color = snapshot.color
    }
}
