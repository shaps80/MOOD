import PixlMemory
import Swift

enum DensePoolBenchmarks {
    static func run(
        scope: borrowing Scope<StorageLayout>
    ) -> [BenchmarkResult] {
        let pool = scope.pool(\.pool)
        let count = BenchmarkWorkload.densePoolCount
        var handles: [DensePool<StorageLayout, UInt64>.Handle] = []
        handles.reserveCapacity(count)

        func fill() {
            pool.removeAll()
            handles.removeAll(keepingCapacity: true)
            for value in 0..<count {
                handles.append(pool.insert(UInt64(value)))
            }
        }

        let insertion = BenchmarkRunner.measure(
            "Dense pool insert",
            operation: "element",
            operationsPerSample: count,
            prepare: { pool.removeAll() },
            body: {
                for value in 0..<count {
                    _ = pool.insert(UInt64(value))
                }
                return UInt64(pool.count)
            }
        )

        let removal = BenchmarkRunner.measure(
            "Dense pool remove",
            operation: "element",
            operationsPerSample: count,
            prepare: { fill() },
            body: {
                var checksum: UInt64 = 0
                for handle in handles.reversed() {
                    checksum &+= pool.remove(handle)
                }
                return checksum
            }
        )

        let lookup = BenchmarkRunner.measure(
            "Dense pool handle lookup",
            operation: "lookup",
            operationsPerSample: count,
            prepare: { fill() },
            body: {
                var checksum: UInt64 = 0
                for handle in handles {
                    checksum &+= pool.value(for: handle)
                }
                return checksum
            }
        )

        let iteration = BenchmarkRunner.measure(
            "Dense pool iteration",
            operation: "element",
            operationsPerSample: count,
            prepare: { fill() },
            body: {
                pool.withElements { elements in
                    var checksum: UInt64 = 0
                    for value in elements {
                        checksum &+= value
                    }
                    return checksum
                }
            }
        )
        return [insertion, removal, lookup, iteration]
    }
}
