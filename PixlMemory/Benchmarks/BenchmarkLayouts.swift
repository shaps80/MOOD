import PixlMemory
import Swift

enum BenchmarkWorkload {
    static let indexedCount = 250_000
    static let rawByteCount = 256_000
    static let densePoolCount = 100_000
}

@Layout("Tiny persistent", policy: .lazy)
struct TinyPersistent {
    static func make(_ layout: inout Layout) {}
}

@Layout("Tiny layout", policy: .lazy)
struct TinyLayout {
    @Region var values: UInt64

    static func make(_ layout: inout Layout) {
        layout.reserve(\.values, count: 8)
    }
}

@Layout("Storage persistent", policy: .lazy)
struct StoragePersistent {
    @Region var state: UInt64

    static func make(_ layout: inout Layout) {
        layout.reserve(\.state, count: 16)
    }
}

@Layout("Storage", policy: .lazy)
struct StorageLayout {
    @Region var indexed: UInt64
    @Region var raw: RawBytes
    @Region(.densePool) var pool: UInt64

    static func make(_ layout: inout Layout) {
        layout.reserve(\.indexed, count: BenchmarkWorkload.indexedCount)
        layout.reserve(\.raw, bytes: .bytes(BenchmarkWorkload.rawByteCount))
        layout.reserve(\.pool, count: BenchmarkWorkload.densePoolCount)
    }
}

struct FrameActor {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var health: UInt32
    var flags: UInt32
}

@Layout("Frame persistent", policy: .lazy)
struct FramePersistent {
    static func make(_ layout: inout Layout) {}
}

@Layout("Frame", policy: .lazy)
struct FrameLayout {
    @Region var renderPositions: SIMD2<Float>
    @Region var scratch: RawBytes
    @Region(.densePool) var actors: FrameActor

    static func make(_ layout: inout Layout) {
        layout.reserve(\.renderPositions, count: 250_000)
        layout.reserve(\.scratch, bytes: .megabytes(1))
        layout.reserve(\.actors, count: 100_000)
    }
}

enum ParticleWorkload {
    static let particleCount = 2_000_000
    static let batchCount = particleCount / 4
}

struct ParticleVector3Batch {
    var x: SIMD4<Float>
    var y: SIMD4<Float>
    var z: SIMD4<Float>

    init(x: SIMD4<Float>, y: SIMD4<Float>, z: SIMD4<Float>) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(repeating value: SIMD3<Float>) {
        x = .init(repeating: value.x)
        y = .init(repeating: value.y)
        z = .init(repeating: value.z)
    }
}

@Layout("Particle persistent", policy: .lazy)
struct ParticlePersistent {
    static func make(_ layout: inout Layout) {}
}

@Layout("Particles", policy: .lazy)
struct ParticleLayout {
    @Region var positionA: ParticleVector3Batch
    @Region var positionB: ParticleVector3Batch
    @Region var velocities: ParticleVector3Batch

    static func make(_ layout: inout Layout) {
        layout.reserve(\.positionA, count: ParticleWorkload.batchCount)
        layout.reserve(\.positionB, count: ParticleWorkload.batchCount)
        layout.reserve(\.velocities, count: ParticleWorkload.batchCount)
    }
}
