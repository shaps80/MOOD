import PixlMemory
import Swift

enum IndexedBufferBenchmarks {
    static func run(
        scope: borrowing Scope<StorageLayout>
    ) -> [BenchmarkResult] {
        let buffer = scope.buffer(\.indexed)
        let count = BenchmarkWorkload.indexedCount

        let append = BenchmarkRunner.measure(
            "Indexed append",
            operation: "element",
            operationsPerSample: count,
            prepare: { buffer.removeAll() },
            body: {
                for value in 0..<count {
                    buffer.append(UInt64(value))
                }
                return buffer.withElements {
                    UInt64(buffer.count) &+ $0[0] &+ $0[count - 1]
                }
            }
        )

        let bulkAppend = BenchmarkRunner.measure(
            "Indexed bulk append",
            operation: "element",
            operationsPerSample: count,
            prepare: { buffer.removeAll() },
            body: {
                buffer.append(count: count) { UInt64($0) }
                return buffer.withElements {
                    UInt64(buffer.count) &+ $0[0] &+ $0[count - 1]
                }
            }
        )

        buffer.removeAll()
        buffer.append(count: count) { UInt64($0) }
        let iteration = BenchmarkRunner.measure(
            "Indexed mutable iteration",
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
        return [append, bulkAppend, iteration]
    }
}
