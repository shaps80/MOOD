@testable import PixlParticles
import Testing

struct EmitterCompilerTests {
    @Test("Compilation is deterministic")
    func deterministicCompilation() {
        let emitter = Emitter(
            capacity: 1_001,
            position: .sphere(radius: 10),
            velocity: .random(-5 ..< 15)
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
                position: .point(.zero),
                velocity: .stationary
            )
        )
        let moving = compiler.compile(
            Emitter(
                capacity: 1_000,
                position: .point(.zero),
                velocity: .random(-1 ..< 1)
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
                position: .point(.zero),
                velocity: .random(0 ..< 0)
            )
        )

        #expect(compiled.storage.velocities == nil)
        #expect(compiled.passes == [.spawn])
    }
}
