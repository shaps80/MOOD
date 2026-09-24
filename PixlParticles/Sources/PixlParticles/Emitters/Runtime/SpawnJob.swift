import Swift

struct SpawnJob {
    let requests: UnsafeMutableBufferPointer<SpawnJobs.Request>
    let particles: UnsafeMutableBufferPointer<Particle>
    let random: RandomSource
    let constants: CompiledEmitter.Constants
    let delta: Float
}
