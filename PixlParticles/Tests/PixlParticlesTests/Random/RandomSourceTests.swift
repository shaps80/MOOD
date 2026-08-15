import Testing
@testable import PixlParticles

@Suite("Random source")
struct RandomSourceTests {
    @Test("Maps a zero address to the Random123 zero vector")
    func addressMapping() {
        let source = RandomSource(seed: 0)

        #expect(
            source.block(at: 0) ==
                .init(0x6627E8D5, 0xE169C58D, 0xBC57AC4C, 0x9B00DBD8)
        )
    }

    @Test("Maps the seed, address, channel, and index to fixed Philox lanes")
    func fullAddressMapping() {
        let source = RandomSource(seed: 0x299F31D0A4093822)

        #expect(
            source.block(
                at: 0x85A308D3243F6A88,
                channel: 0x13198A2E,
                index: 0x03707344
            ) == .init(0xD16CFE09, 0x94FDCCEB, 0x5001E420, 0x24126EA1)
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

    @Test("Maps integers to exact unit-float bit patterns")
    func unitFloatBitPatterns() {
        #expect(RandomSource.unitFloat(from: 0).bitPattern == 0x00000000)
        #expect(RandomSource.unitFloat(from: 0x00000100).bitPattern == 0x33800000)
        #expect(RandomSource.unitFloat(from: 0x80000000).bitPattern == 0x3F000000)
        #expect(RandomSource.unitFloat(from: .max).bitPattern == 0x3F7FFFFF)
    }

    @Test("Ignores the lower eight bits")
    func lowerBits() {
        let expected = RandomSource.unitFloat(from: 0x12345600)

        #expect(RandomSource.unitFloat(from: 0x123456FF) == expected)
    }

    @Test("Maps integers into exact ranged-float bit patterns")
    func rangedFloatBitPatterns() {
        let range: Range<Float> = -10..<10

        #expect(RandomSource.float(from: 0, in: range).bitPattern == 0xC1200000)
        #expect(RandomSource.float(from: 0x80000000, in: range).bitPattern == 0)
        #expect(RandomSource.float(from: .max, in: range).bitPattern == 0x411FFFFE)
    }

    @Test("Never rounds up to the excluded bound")
    func excludedUpperBound() {
        let lower: Float = 1
        let range = lower..<lower.nextUp

        #expect(RandomSource.float(from: .max, in: range) == lower)
    }

    @Test("Maps integers into exact closed unit-range bit patterns")
    func closedRangeBitPatterns() {
        let range: ClosedRange<Float> = 0...1

        #expect(RandomSource.float(from: 0, in: range).bitPattern == 0x00000000)
        #expect(RandomSource.float(from: 0x7FFFFF00, in: range).bitPattern == 0x3EFFFFFF)
        #expect(RandomSource.float(from: 0x80000000, in: range).bitPattern == 0x3F000001)
        #expect(RandomSource.float(from: .max, in: range).bitPattern == 0x3F800000)
    }

    @Test("Returns both closed-range bounds exactly")
    func closedRangeBounds() {
        let range: ClosedRange<Float> = -10...10

        #expect(RandomSource.float(from: 0, in: range) == range.lowerBound)
        #expect(RandomSource.float(from: .max, in: range) == range.upperBound)
    }

    @Test("Supports a single-value closed range")
    func singleValueClosedRange() {
        let range: ClosedRange<Float> = 42...42

        #expect(RandomSource.float(from: 0x12345678, in: range) == 42)
    }
}
