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
}
