@testable import PixlParticles
import Testing

struct EmitterCompilerTests {
    @Test("Compilation is deterministic")
    func deterministicCompilation() {
        let emitter = Emitter(
            capacity: 1_001,
            spawnRegion: .sphere(radius: 10),
            velocity: .init([
                .set(.random(from: [-5, -5, -5], to: [15, 15, 15], variation: .perValue)),
            ])
        )
        let compiler = EmitterCompiler()

        #expect(compiler.compile(emitter) == compiler.compile(emitter))
    }

    @Test("Stationary emitters omit velocity storage and integration")
    func stationaryLayout() {
        let compiler = EmitterCompiler()
        let stationary = compiler.compile(
            Emitter(
                capacity: 1_000,
                spawnRegion: .point(.zero),
                velocity: .init()
            )
        )
        let moving = compiler.compile(
            Emitter(
                capacity: 1_000,
                spawnRegion: .point(.zero),
                velocity: .init([
                    .set(.random(from: [-1, -1, -1], to: [1, 1, 1], variation: .perValue)),
                ])
            )
        )

        #expect(stationary.storage.previousPositions == nil)
        #expect(stationary.storage.velocities == nil)
        #expect(stationary.passes == [.spawn])
        #expect(moving.storage.previousPositions != nil)
        #expect(moving.storage.velocities != nil)
        #expect(moving.passes == [.spawn, .integratePosition])
        #expect(stationary.storage.byteCount < moving.storage.byteCount)
    }

    @Test("Zero random velocity compiles as stationary")
    func foldsZeroVelocity() {
        let compiled = EmitterCompiler().compile(
            Emitter(
                capacity: 100,
                spawnRegion: .point(.zero),
                velocity: .init([.set(.zero)])
            )
        )

        #expect(compiled.storage.velocities == nil)
        #expect(compiled.passes == [.spawn])
    }
}
