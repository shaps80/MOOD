@testable import PixlParticles
import Testing

struct MetadataTests {
    @Test("Initial handles resolve directly to dense indices")
    func initialMapping() {
        let metadata = Metadata(capacity: 5, count: 5)

        for index in 0..<5 {
            let id = Particle.ID(index)
            let resolved = metadata.resolve(id)
            #expect(resolved?.slot == UInt32(index))
            #expect(resolved?.index == index)
            #expect(metadata.id(for: UInt32(index)) == id)
        }

        #expect(metadata.byteCount == 30)
    }

    @Test("Released handles become stale and slots are reused LIFO")
    func reuse() throws {
        let metadata = Metadata(capacity: 5, count: 5)

        metadata.release(1)
        metadata.release(3)

        #expect(metadata.resolve(1) == nil)
        #expect(metadata.resolve(3) == nil)

        let first = try #require(metadata.allocate(at: 3))
        let second = try #require(metadata.allocate(at: 4))

        #expect(first.slot == 3)
        #expect(first.id == Particle.ID(1) << 32 | 3)
        #expect(second.slot == 1)
        #expect(second.id == Particle.ID(1) << 32 | 1)
        #expect(metadata.resolve(first.id)?.index == 3)
        #expect(metadata.resolve(second.id)?.index == 4)
    }

    @Test("Reset restores generation-zero direct mapping")
    func reset() {
        let metadata = Metadata(capacity: 3, count: 3)
        metadata.release(1)
        _ = metadata.allocate(at: 2)

        metadata.reset(count: 3)

        #expect(metadata.resolve(0)?.index == 0)
        #expect(metadata.resolve(1)?.index == 1)
        #expect(metadata.resolve(2)?.index == 2)
        #expect(metadata.resolve(Particle.ID(1) << 32 | 1) == nil)
    }
}
