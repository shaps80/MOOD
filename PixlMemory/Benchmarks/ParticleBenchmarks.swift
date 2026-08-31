import PixlMemory
import Swift

enum ParticleBenchmarks {
    static func run() -> [BenchmarkResult] {
        let arena = try! Arena(
            ParticlePersistent.self,
            layouts: ParticleLayout.self,
            logging: .disabled
        )
        let scope = arena.acquire(ParticleLayout.self)
        let positionA = scope.buffer(\.positionA)
        let positionB = scope.buffer(\.positionB)
        let velocities = scope.buffer(\.velocities)
        let batchCount = ParticleWorkload.batchCount

        positionA.append(count: batchCount) { _ in
            ParticleVector3Batch(repeating: .zero)
        }
        positionB.append(count: batchCount) { _ in
            ParticleVector3Batch(repeating: .zero)
        }
        velocities.append(count: batchCount, makeVelocity)

        var pass = 0
        let perParticle = BenchmarkRunner.measure(
            "Particle integration (2M)",
            operation: "particle",
            operationsPerSample: ParticleWorkload.particleCount,
            prepare: {},
            body: {
                pass += 1
                if pass.isMultiple(of: 2) {
                    return integrate(
                        source: positionB,
                        destination: positionA,
                        velocities: velocities
                    )
                }
                return integrate(
                    source: positionA,
                    destination: positionB,
                    velocities: velocities
                )
            }
        )

        validate(
            positionA: positionA,
            positionB: positionB,
            measuredPasses: BenchmarkRunner.warmupCount
                + BenchmarkRunner.sampleCount
        )

        let frame = BenchmarkResult(
            name: "Particle integration (2M)",
            operation: "frame",
            medianNanoseconds: perParticle.medianNanoseconds
                * Double(ParticleWorkload.particleCount),
            p95Nanoseconds: perParticle.p95Nanoseconds
                * Double(ParticleWorkload.particleCount),
            maximumNanoseconds: perParticle.maximumNanoseconds
                * Double(ParticleWorkload.particleCount),
            checksum: 0
        )
        scope.release()
        return [perParticle, frame]
    }

    private static func integrate(
        source: IndexedBuffer<ParticleVector3Batch>,
        destination: IndexedBuffer<ParticleVector3Batch>,
        velocities: IndexedBuffer<ParticleVector3Batch>
    ) -> UInt64 {
        let delta: Float = 1 / 60
        return source.withElements { source in
            velocities.withElements { velocities in
                destination.withMutableElements { destination in
                    for index in source.indices {
                        destination[index].x = source[index].x
                            + velocities[index].x * delta
                        destination[index].y = source[index].y
                            + velocities[index].y * delta
                        destination[index].z = source[index].z
                            + velocities[index].z * delta
                    }

                    return UInt64(destination[0].x[0].bitPattern)
                        &+ UInt64(
                            destination[destination.count - 1].z[3].bitPattern
                        )
                }
            }
        }
    }

    private static func makeVelocity(_ index: Int) -> ParticleVector3Batch {
        let base = Float(index % 97 + 1) * 0.001
        return ParticleVector3Batch(
            x: SIMD4(base, base + 0.001, base + 0.002, base + 0.003),
            y: SIMD4(base + 0.004, base + 0.005, base + 0.006, base + 0.007),
            z: SIMD4(base + 0.008, base + 0.009, base + 0.010, base + 0.011)
        )
    }

    private static func validate(
        positionA: IndexedBuffer<ParticleVector3Batch>,
        positionB: IndexedBuffer<ParticleVector3Batch>,
        measuredPasses: Int
    ) {
        precondition(measuredPasses.isMultiple(of: 2))
        let delta: Float = 1 / 60
        positionA.withElements { positionA in
            positionB.withElements { positionB in
                for index in positionA.indices {
                    let velocity = makeVelocity(index)
                    validate(
                        positionA[index],
                        expected: velocity,
                        scale: delta * Float(measuredPasses)
                    )
                    validate(
                        positionB[index],
                        expected: velocity,
                        scale: delta * Float(measuredPasses - 1)
                    )
                }
            }
        }
    }

    private static func validate(
        _ value: ParticleVector3Batch,
        expected: ParticleVector3Batch,
        scale: Float
    ) {
        for lane in 0..<4 {
            precondition(abs(value.x[lane] - expected.x[lane] * scale) < 0.0001)
            precondition(abs(value.y[lane] - expected.y[lane] * scale) < 0.0001)
            precondition(abs(value.z[lane] - expected.z[lane] * scale) < 0.0001)
        }
    }
}
