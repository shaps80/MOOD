import Testing
@testable import PixlParticles

@Suite("Random source")
struct RandomSourceTests {
    @Test("Maps the seed and address to fixed Philox lanes")
    func addressMapping() {
        let source = RandomSource(seed: 0)

        #expect(
            source.block(at: 0) ==
                .init(0x6627E8D5, 0xE169C58D, 0xBC57AC4C, 0x9B00DBD8)
        )
    }

    @Test("Addresses select distinct blocks")
    func addresses() {
        let source = RandomSource(seed: 0x0123456789ABCDEF)

        #expect(source.block(at: 0) != source.block(at: 1))
    }

    @Test("Seeds select distinct blocks")
    func seeds() {
        let first = RandomSource(seed: 0)
        let second = RandomSource(seed: 1)

        #expect(first.block(at: 0) != second.block(at: 0))
    }
}
