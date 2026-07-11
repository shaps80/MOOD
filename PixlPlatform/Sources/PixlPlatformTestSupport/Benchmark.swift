import Swift

package struct BenchmarkResult: Sendable {
    package let name: String
    package let operationsPerIteration: UInt64
    package let iterations: UInt64
    package let averageNanoseconds: UInt64
    package let minimumNanoseconds: UInt64
    package let maximumNanoseconds: UInt64
    package let checksum: UInt64

    package var nanosecondsPerOperationHundredths: UInt64 {
        guard operationsPerIteration > 0 else { return 0 }
        return averageNanoseconds &* 100 / operationsPerIteration
    }
}

package enum Benchmark {
    package static func measure(
        name: String,
        operationsPerIteration: UInt64,
        warmupIterations: Int,
        iterations: Int,
        _ body: () -> UInt64
    ) -> BenchmarkResult {
        precondition(iterations > 0)

        var checksum: UInt64 = 0

        for _ in 0..<warmupIterations {
            checksum &+= body()
        }

        let clock = ContinuousClock()
        var totalNanoseconds: UInt64 = 0
        var minimumNanoseconds = UInt64.max
        var maximumNanoseconds: UInt64 = 0

        for _ in 0..<iterations {
            let start = clock.now
            checksum &+= body()
            let elapsed = nanoseconds(start.duration(to: clock.now))

            totalNanoseconds &+= elapsed
            minimumNanoseconds = min(minimumNanoseconds, elapsed)
            maximumNanoseconds = max(maximumNanoseconds, elapsed)
        }

        return BenchmarkResult(
            name: name,
            operationsPerIteration: operationsPerIteration,
            iterations: UInt64(iterations),
            averageNanoseconds: totalNanoseconds / UInt64(iterations),
            minimumNanoseconds: minimumNanoseconds,
            maximumNanoseconds: maximumNanoseconds,
            checksum: checksum
        )
    }

    private static func nanoseconds(_ duration: Duration) -> UInt64 {
        let components = duration.components
        precondition(components.seconds >= 0)
        precondition(components.attoseconds >= 0)

        return UInt64(components.seconds) &* 1_000_000_000
            &+ UInt64(components.attoseconds) / 1_000_000_000
    }
}

