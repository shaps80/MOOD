import PixlMemory
import Swift

enum GrowingBufferBenchmarks {
    static func run() -> [BenchmarkResult] {
        let count = BenchmarkWorkload.indexedCount
        let arena = try! Arena(GrowingStorage.self, logging: .disabled)
        let buffer = arena.buffer(\.indexed)
        buffer.append(count: count) { UInt64($0) }
        let fixedArena = try! Arena(FixedComparisonStorage.self, logging: .disabled)
        let fixed = fixedArena.buffer(\.indexed)
        let append: (IndexedBuffer<UInt64>) -> UInt64 = { target in
            for value in 0..<count {
                target.append(UInt64(value))
            }
            return target.withElements {
                UInt64(target.count) &+ $0[0] &+ $0[count - 1]
            }
        }
        let retainedAppend = BenchmarkRunner.measureAlternating(
            firstName: "Paired fixed append",
            secondName: "Growing retained append",
            operation: "element",
            operationsPerSample: count,
            prepareFirst: { fixed.removeAll() },
            first: { append(fixed) },
            prepareSecond: { buffer.removeAll() },
            second: { append(buffer) }
        )

        let coldAppend = BenchmarkRunner.measure(
            "Growing cold append",
            operation: "element",
            operationsPerSample: count,
            prepare: {},
            body: {
                let coldArena = try! Arena(GrowingStorage.self, logging: .disabled)
                let cold = coldArena.buffer(\.indexed)
                for value in 0..<count {
                    cold.append(UInt64(value))
                }
                return cold.withElements {
                    UInt64(cold.count) &+ $0[0] &+ $0[count - 1]
                }
            }
        )

        let coldBulkAppend = BenchmarkRunner.measure(
            "Growing cold bulk append",
            operation: "element",
            operationsPerSample: count,
            prepare: {},
            body: {
                let coldArena = try! Arena(GrowingStorage.self, logging: .disabled)
                let cold = coldArena.buffer(\.indexed)
                cold.append(count: count) { UInt64($0) }
                return cold.withElements {
                    UInt64(cold.count) &+ $0[0] &+ $0[count - 1]
                }
            }
        )

        let iteration = BenchmarkRunner.measure(
            "Growing mutable iteration",
            operation: "element",
            operationsPerSample: count,
            prepare: {},
            body: {
                buffer.withMutableElements { elements -> UInt64 in
                    var checksum: UInt64 = 0
                    for index in elements.indices {
                        elements[index] &+= 1
                        checksum &+= elements[index]
                    }
                    return checksum
                }
            }
        )

        return retainedAppend + [
            growthEvent(at: 1_024, name: "Growth 1K → 2K"),
            growthEvent(at: 16_384, name: "Growth 16K → 32K"),
            growthEvent(at: 131_072, name: "Growth 128K → 256K"),
            growthEvent(at: 1_048_576, name: "Growth 1M → 2M"),
            coldAppend,
            coldBulkAppend,
            iteration
        ]
    }

    private static func growthEvent(
        at capacity: Int,
        name: String
    ) -> BenchmarkResult {
        var buffer: IndexedBuffer<UInt64>?
        return BenchmarkRunner.measure(
            name,
            operation: "growth",
            operationsPerSample: 1,
            prepare: {
                buffer = nil
                let nextArena = try! Arena(GrowingStorage.self, logging: .disabled)
                let nextBuffer = nextArena.buffer(\.indexed)
                nextBuffer.append(count: capacity) { UInt64($0) }
                precondition(nextBuffer.capacity == capacity)
                buffer = nextBuffer
            },
            body: {
                buffer!.append(UInt64(capacity))
                return UInt64(buffer!.capacity) &+ UInt64(buffer!.count)
            }
        )
    }
}
