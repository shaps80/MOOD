import Swift
import PixlBackend

package struct ResourcePoolBenchmarkReport: Sendable {
    package let coldStart: BenchmarkResult
    package let sequentialLookup: BenchmarkResult
    package let randomLookup: BenchmarkResult
    package let update: BenchmarkResult
    package let churn: BenchmarkResult

    package func printResults() {
        print("ResourcePool — \(ResourcePoolSuite.elementCount) resources")
        print("Platform: \(platformName)")
        print("Configuration: release")
        print("")

        printResult(coldStart)
        printResult(sequentialLookup)
        printResult(randomLookup)
        printResult(update)
        printResult(churn)

        // Keep every measured workload observable to the optimizer.
        let checksum = coldStart.checksum
            &+ sequentialLookup.checksum
            &+ randomLookup.checksum
            &+ update.checksum
            &+ churn.checksum
        print("Checksum: \(checksum)")
    }

    private var platformName: String {
        #if os(WASI)
        "WASM/WASI"
        #elseif os(Windows)
        "Windows"
        #elseif os(Linux)
        "Linux"
        #elseif os(macOS)
        "macOS"
        #else
        "Unknown"
        #endif
    }

    private func printResult(_ result: BenchmarkResult) {
        let perOperation = result.nanosecondsPerOperationHundredths
        print(result.name)
        print("  Average: \(milliseconds(result.averageNanoseconds)) ms")
        print("  Per operation: \(decimalHundredths(perOperation)) ns")
        print("  Min: \(milliseconds(result.minimumNanoseconds)) ms")
        print("  Max: \(milliseconds(result.maximumNanoseconds)) ms")
        print("  Iterations: \(result.iterations)")
    }

    private func milliseconds(_ nanoseconds: UInt64) -> String {
        decimalThousandths(nanoseconds / 1_000)
    }

    private func decimalThousandths(_ thousandths: UInt64) -> String {
        let whole = thousandths / 1_000
        let fraction = thousandths % 1_000
        return "\(whole).\(leftPadded(fraction, width: 3))"
    }

    private func decimalHundredths(_ hundredths: UInt64) -> String {
        let whole = hundredths / 100
        let fraction = hundredths % 100
        return "\(whole).\(leftPadded(fraction, width: 2))"
    }

    private func leftPadded(_ value: UInt64, width: Int) -> String {
        let value = String(value)
        return String(repeating: "0", count: max(0, width - value.count)) + value
    }
}

package enum ResourcePoolSuite {
    package static let elementCount: UInt32 = 150_000

    package static func runChecks() throws {
        let pool = ResourcePool<UInt64>(capacity: 2)

        guard let first = pool.insert(10), let second = pool.insert(20) else {
            throw CheckFailure("expected initial insertions to succeed")
        }

        try require(pool.count == 2, "expected two live resources")
        try require(pool.insert(30) == nil, "expected fixed capacity to be enforced")

        var firstValue: UInt64 = 0
        try require(pool.withValue(for: first) { firstValue = $0.pointee } != nil, "expected lookup to succeed")
        try require(firstValue == 10, "expected lookup to return stored value")

        try require(pool.update(first) { $0.pointee = 11 } != nil, "expected update to succeed")
        try require(pool.remove(first), "expected removal to succeed")
        try require(!pool.contains(first), "expected removed handle to become stale")
        try require(pool.withValue(for: first) { _ in } == nil, "expected stale lookup to fail")

        guard let replacement = pool.insert(30) else {
            throw CheckFailure("expected removed slot to be reusable")
        }

        try require(replacement.index == first.index, "expected free-list slot reuse")
        try require(replacement.generation != first.generation, "expected generation advancement")
        try require(pool.contains(second), "expected unrelated handle to remain valid")
    }

    package static func runBenchmarks() -> ResourcePoolBenchmarkReport {
        let operations = UInt64(elementCount)

        let coldStart = Benchmark.measure(
            name: "Cold start lifecycle",
            operationsPerIteration: operations * 3,
            warmupIterations: 2,
            iterations: 10,
            coldStartIteration
        )

        let sequentialFixture = Fixture(count: elementCount)
        let sequentialLookup = Benchmark.measure(
            name: "Sequential lookup",
            operationsPerIteration: operations,
            warmupIterations: 10,
            iterations: 100
        ) {
            sequentialFixture.lookupChecksum()
        }

        let randomFixture = Fixture(count: elementCount)
        randomFixture.shuffleIDs()
        let randomLookup = Benchmark.measure(
            name: "Random-order lookup",
            operationsPerIteration: operations,
            warmupIterations: 10,
            iterations: 100
        ) {
            randomFixture.lookupChecksum()
        }

        let updateFixture = Fixture(count: elementCount)
        let update = Benchmark.measure(
            name: "In-place update",
            operationsPerIteration: operations,
            warmupIterations: 10,
            iterations: 100
        ) {
            updateFixture.updateAll()
        }

        let churnFixture = Fixture(count: elementCount)
        let churn = Benchmark.measure(
            name: "Remove/reinsert churn",
            operationsPerIteration: operations * 2,
            warmupIterations: 2,
            iterations: 10
        ) {
            churnFixture.churn()
        }

        return ResourcePoolBenchmarkReport(
            coldStart: coldStart,
            sequentialLookup: sequentialLookup,
            randomLookup: randomLookup,
            update: update,
            churn: churn
        )
    }

    private static func coldStartIteration() -> UInt64 {
        let pool = ResourcePool<UInt64>(capacity: elementCount)
        let ids = UnsafeMutablePointer<ResourceID>.allocate(capacity: Int(elementCount))

        for index in 0..<elementCount {
            ids.advanced(by: Int(index)).initialize(to: pool.insert(UInt64(index))!)
        }

        for index in 0..<elementCount {
            _ = pool.update(ids[Int(index)]) { $0.pointee &+= 1 }
        }

        for index in 0..<elementCount {
            precondition(pool.remove(ids[Int(index)]))
        }

        let checksum = UInt64(pool.count) &+ ids[0].rawValue
        ids.deinitialize(count: Int(elementCount))
        ids.deallocate()
        return checksum
    }
}

private final class Fixture {
    let pool: ResourcePool<UInt64>
    let ids: UnsafeMutablePointer<ResourceID>
    let count: UInt32

    init(count: UInt32) {
        self.count = count
        pool = ResourcePool(capacity: count)
        ids = .allocate(capacity: Int(count))

        for index in 0..<count {
            ids.advanced(by: Int(index)).initialize(to: pool.insert(UInt64(index))!)
        }
    }

    deinit {
        ids.deinitialize(count: Int(count))
        ids.deallocate()
    }

    func lookupChecksum() -> UInt64 {
        var checksum: UInt64 = 0

        for index in 0..<count {
            pool.withValue(for: ids[Int(index)]) { checksum &+= $0.pointee }
        }

        return checksum
    }

    func updateAll() -> UInt64 {
        for index in 0..<count {
            pool.update(ids[Int(index)]) { $0.pointee &+= 1 }
        }

        var checksum: UInt64 = 0
        pool.withValue(for: ids[0]) { checksum = $0.pointee }
        return checksum
    }

    func churn() -> UInt64 {
        for index in 0..<count {
            precondition(pool.remove(ids[Int(index)]))
        }

        var checksum: UInt64 = 0
        for index in 0..<count {
            let id = pool.insert(UInt64(index))!
            ids[Int(index)] = id
            checksum &+= id.rawValue
        }

        return checksum
    }

    func shuffleIDs() {
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15

        for index in stride(from: Int(count) - 1, through: 1, by: -1) {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27

            let other = Int(state % UInt64(index + 1))
            let value = ids[index]
            ids[index] = ids[other]
            ids[other] = value
        }
    }
}
