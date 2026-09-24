import Swift

/// Allocated once per emitter; only generated particles are written concurrently.
final class SpawnJobs {
    struct Request {
        var index: Int = 0
        var slot: UInt32 = 0
        var id: Particle.ID = 0
    }
    let requests: UnsafeMutableBufferPointer<Request>
    let particles: UnsafeMutableBufferPointer<Particle>

    init(capacity: Int) {
        requests = .allocate(capacity: capacity)
        requests.initialize(repeating: Request())
        particles = .allocate(capacity: capacity)
        particles.initialize(repeating: Particle(id: 0, position: .zero, velocity: .zero, color: .white))
    }
    deinit {
        requests.deinitialize()
        requests.deallocate()
        particles.deinitialize()
        particles.deallocate()
    }
}
