import Swift

@main
struct RandomBenchmarks {
    private static let measuredBlockCount: UInt64 = 10_000_000
    private static let warmupBlockCount: UInt64 = 1_000_000
    private static let sampleCount = 5

    static func main() {
        _ = generateRawBlocks(count: warmupBlockCount)
        _ = generateHalfOpenFloats(count: warmupBlockCount)
        _ = generateClosedFloats(count: warmupBlockCount)

        benchmark("Philox raw words", body: generateRawBlocks)
        benchmark("Half-open ranged floats", body: generateHalfOpenFloats)
        benchmark("Closed ranged floats", body: generateClosedFloats)
    }

    @_optimize(none)
    private static func benchmark(
        _ name: String,
        body: (UInt64) -> UInt64
    ) {
        let clock = ContinuousClock()
        var samples: [Double] = []
        var checksum: UInt64 = 0

        samples.reserveCapacity(sampleCount)

        for _ in 0..<sampleCount {
            let start = clock.now
            checksum ^= body(measuredBlockCount)
            let duration = start.duration(to: clock.now)
            let components = duration.components
            let seconds = Double(components.seconds)
                + Double(components.attoseconds) / 1_000_000_000_000_000_000

            samples.append(seconds)
        }

        samples.sort()

        let seconds = samples[sampleCount / 2]
        let valueCount = Double(measuredBlockCount) * 4
        let millionsPerSecond = valueCount / seconds / 1_000_000

        print("\(name): \(millionsPerSecond) million values/s [\(checksum)]")
    }

    @inline(never)
    private static func generateRawBlocks(count: UInt64) -> UInt64 {
        let source = RandomSource(seed: 0x0123456789ABCDEF)
        var checksum: UInt64 = 0

        for address in 0..<count {
            let block = source.block(at: address)
            checksum &+= UInt64(block.x0)
            checksum &+= UInt64(block.x1)
            checksum &+= UInt64(block.x2)
            checksum &+= UInt64(block.x3)
        }

        return checksum
    }

    @inline(never)
    private static func generateHalfOpenFloats(count: UInt64) -> UInt64 {
        let source = RandomSource(seed: 0x0123456789ABCDEF)
        let range: Range<Float> = -100..<100
        var checksum: UInt64 = 0

        for address in 0..<count {
            let block = source.block(at: address)
            checksum &+= UInt64(RandomSource.float(from: block.x0, in: range).bitPattern)
            checksum &+= UInt64(RandomSource.float(from: block.x1, in: range).bitPattern)
            checksum &+= UInt64(RandomSource.float(from: block.x2, in: range).bitPattern)
            checksum &+= UInt64(RandomSource.float(from: block.x3, in: range).bitPattern)
        }

        return checksum
    }

    @inline(never)
    private static func generateClosedFloats(count: UInt64) -> UInt64 {
        let source = RandomSource(seed: 0x0123456789ABCDEF)
        let range: ClosedRange<Float> = -100...100
        var checksum: UInt64 = 0

        for address in 0..<count {
            let block = source.block(at: address)
            checksum &+= UInt64(RandomSource.float(from: block.x0, in: range).bitPattern)
            checksum &+= UInt64(RandomSource.float(from: block.x1, in: range).bitPattern)
            checksum &+= UInt64(RandomSource.float(from: block.x2, in: range).bitPattern)
            checksum &+= UInt64(RandomSource.float(from: block.x3, in: range).bitPattern)
        }

        return checksum
    }
}
