import Testing
@testable import PixlParticles

@Suite("Philox4x32-10")
struct Philox4x32Tests {
    @Test("Matches the Random123 zero vector")
    func zeroVector() {
        let output = Philox4x32.generate(
            counter: .init(0, 0, 0, 0),
            key: .init(0, 0)
        )

        #expect(output == .init(0x6627E8D5, 0xE169C58D, 0xBC57AC4C, 0x9B00DBD8))
    }

    @Test("Matches the Random123 all-ones vector")
    func allOnesVector() {
        let output = Philox4x32.generate(
            counter: .init(.max, .max, .max, .max),
            key: .init(.max, .max)
        )

        #expect(output == .init(0x408F276D, 0x41C83B0E, 0xA20BC7C6, 0x6D5451FD))
    }

    @Test("Matches the Random123 pi vector")
    func piVector() {
        let output = Philox4x32.generate(
            counter: .init(0x243F6A88, 0x85A308D3, 0x13198A2E, 0x03707344),
            key: .init(0xA4093822, 0x299F31D0)
        )

        #expect(output == .init(0xD16CFE09, 0x94FDCCEB, 0x5001E420, 0x24126EA1))
    }

    @Test("Matches a 65,536-counter Random123 corpus")
    func referenceCorpus() {
        // Generated independently with DEShawResearch/random123 at 9545ff6.
        var hash: UInt64 = 14_695_981_039_346_656_037

        for i in UInt32(0)..<65_536 {
            let rotated = (i << 13) | (i >> 19)
            let output = Philox4x32.generate(
                counter: .init(
                    i,
                    i &* 0x9E3779B9,
                    ~i,
                    rotated ^ 0xA5A5A5A5
                ),
                key: .init(
                    i &* 0xBB67AE85,
                    ~(i &* 0xD2511F53)
                )
            )

            hash = mix(output.x0, into: hash)
            hash = mix(output.x1, into: hash)
            hash = mix(output.x2, into: hash)
            hash = mix(output.x3, into: hash)
        }

        #expect(hash == 0x40C8A13CF0C6F7EB)
    }

    private func mix(_ word: UInt32, into hash: UInt64) -> UInt64 {
        (hash ^ UInt64(word)) &* 1_099_511_628_211
    }
}
