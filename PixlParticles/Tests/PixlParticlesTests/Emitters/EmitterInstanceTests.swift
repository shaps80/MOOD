@testable import PixlParticles
import Testing

struct EmitterInstanceTests {
    @Test("Constant edits preserve the emitter arena")
    func constantEdit() {
        let compiler = EmitterCompiler()
        var emitter = Emitter(
            capacity: 1_000,
            position: .sphere(radius: 10)
        )
        let instance = EmitterInstance(compiled: compiler.compile(emitter))
        let identity = instance.arenaIdentity

        emitter.color = .init(red: 4, green: 1, blue: 0.25)
        emitter.size = [3, 6]
        emitter.rotation = 0.5

        #expect(instance.apply(compiler.compile(emitter)) == .reusedArena)
        #expect(instance.arenaIdentity == identity)
    }

    @Test("Storage-layout edits rebuild only the emitter arena")
    func structuralEdit() {
        let compiler = EmitterCompiler()
        var emitter = Emitter(
            capacity: 1_000,
            position: .point(.zero),
            velocity: .stationary
        )
        let instance = EmitterInstance(compiled: compiler.compile(emitter))
        let identity = instance.arenaIdentity
        let stationaryByteCount = instance.arenaByteCount

        emitter.velocity = .random(-1 ... 1)

        #expect(instance.apply(compiler.compile(emitter)) == .rebuiltArena)
        #expect(instance.arenaIdentity != identity)
        #expect(instance.arenaByteCount > stationaryByteCount)
    }

    @Test("Renderer edits preserve particle storage")
    func rendererEdit() {
        let compiler = EmitterCompiler()
        var emitter = Emitter(
            capacity: 1_000,
            position: .point(.zero)
        )
        let instance = EmitterInstance(compiled: compiler.compile(emitter))
        let identity = instance.arenaIdentity

        emitter.renderers = [.init(mode: .billboard)]

        #expect(instance.apply(compiler.compile(emitter)) == .reusedArena)
        #expect(instance.arenaIdentity == identity)
    }
}
