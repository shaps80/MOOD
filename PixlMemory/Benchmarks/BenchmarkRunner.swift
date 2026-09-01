import Swift

enum BenchmarkRunner {
    static let warmupCount = 5
    static let sampleCount = 31

    static func measure(
        _ name: String,
        operation: String,
        operationsPerSample: Int,
        prepare: () -> Void,
        body: () -> UInt64
    ) -> BenchmarkResult {
        precondition(operationsPerSample > 0)
        var checksum: UInt64 = 0
        for _ in 0..<warmupCount {
            prepare()
            checksum &+= body()
        }

        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            prepare()
            let start = ContinuousClock.now
            checksum &+= body()
            let elapsed = ContinuousClock.now - start
            let components = elapsed.components
            let nanoseconds = Double(components.seconds) * 1_000_000_000
                + Double(components.attoseconds) * 1e-9
            samples.append(nanoseconds / Double(operationsPerSample))
        }
        samples.sort()
        return BenchmarkResult(
            name: name,
            operation: operation,
            medianNanoseconds: samples[samples.count / 2],
            p95Nanoseconds: samples[Int(Double(samples.count - 1) * 0.95)],
            maximumNanoseconds: samples[samples.count - 1],
            checksum: checksum
        )
    }

    static func measureAlternating(
        firstName: String,
        secondName: String,
        operation: String,
        operationsPerSample: Int,
        prepareFirst: () -> Void,
        first: () -> UInt64,
        prepareSecond: () -> Void,
        second: () -> UInt64
    ) -> [BenchmarkResult] {
        precondition(operationsPerSample > 0)
        var firstChecksum: UInt64 = 0
        var secondChecksum: UInt64 = 0
        for index in 0..<warmupCount {
            if index.isMultiple(of: 2) {
                prepareFirst()
                firstChecksum &+= first()
                prepareSecond()
                secondChecksum &+= second()
            } else {
                prepareSecond()
                secondChecksum &+= second()
                prepareFirst()
                firstChecksum &+= first()
            }
        }

        var firstSamples: [Double] = []
        var secondSamples: [Double] = []
        firstSamples.reserveCapacity(sampleCount)
        secondSamples.reserveCapacity(sampleCount)
        for index in 0..<sampleCount {
            if index.isMultiple(of: 2) {
                prepareFirst()
                firstChecksum &+= time(first, into: &firstSamples, operations: operationsPerSample)
                prepareSecond()
                secondChecksum &+= time(second, into: &secondSamples, operations: operationsPerSample)
            } else {
                prepareSecond()
                secondChecksum &+= time(second, into: &secondSamples, operations: operationsPerSample)
                prepareFirst()
                firstChecksum &+= time(first, into: &firstSamples, operations: operationsPerSample)
            }
        }
        firstSamples.sort()
        secondSamples.sort()
        return [
            result(firstName, operation: operation, samples: firstSamples, checksum: firstChecksum),
            result(secondName, operation: operation, samples: secondSamples, checksum: secondChecksum)
        ]
    }

    private static func time(
        _ body: () -> UInt64,
        into samples: inout [Double],
        operations: Int
    ) -> UInt64 {
        let start = ContinuousClock.now
        let checksum = body()
        let elapsed = ContinuousClock.now - start
        let components = elapsed.components
        let nanoseconds = Double(components.seconds) * 1_000_000_000
            + Double(components.attoseconds) * 1e-9
        samples.append(nanoseconds / Double(operations))
        return checksum
    }

    private static func result(
        _ name: String,
        operation: String,
        samples: [Double],
        checksum: UInt64
    ) -> BenchmarkResult {
        BenchmarkResult(
            name: name,
            operation: operation,
            medianNanoseconds: samples[samples.count / 2],
            p95Nanoseconds: samples[Int(Double(samples.count - 1) * 0.95)],
            maximumNanoseconds: samples[samples.count - 1],
            checksum: checksum
        )
    }
}
