import PixlMemory
import Swift

enum RawBufferBenchmarks {
    static func run(
        scope: borrowing Scope<StorageLayout>
    ) -> [BenchmarkResult] {
        let buffer = scope.buffer(\.raw)
        let chunkSize = 64
        let chunkCount = BenchmarkWorkload.rawByteCount / chunkSize

        let append = BenchmarkRunner.measure(
            "Raw append (64 bytes)",
            operation: "chunk",
            operationsPerSample: chunkCount,
            prepare: { buffer.removeAll() },
            body: {
                for value in 0..<chunkCount {
                    buffer.append(bytes: .bytes(chunkSize)) { bytes in
                        bytes.initializeMemory(
                            as: UInt8.self,
                            repeating: UInt8(truncatingIfNeeded: value)
                        )
                    }
                }
                return buffer.withBytes {
                    buffer.count.rawValue
                        &+ UInt64($0[0])
                        &+ UInt64($0[$0.count - 1])
                }
            }
        )

        buffer.removeAll()
        buffer.append(bytes: .bytes(BenchmarkWorkload.rawByteCount)) { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 1)
        }
        let iteration = BenchmarkRunner.measure(
            "Raw mutable iteration",
            operation: "byte",
            operationsPerSample: BenchmarkWorkload.rawByteCount,
            prepare: {},
            body: {
                buffer.withMutableBytes { bytes -> UInt64 in
                    var checksum: UInt64 = 0
                    for index in bytes.indices {
                        bytes[index] &+= 1
                        checksum &+= UInt64(bytes[index])
                    }
                    return checksum
                }
            }
        )

        let measuredPasses = BenchmarkRunner.warmupCount
            + BenchmarkRunner.sampleCount
        let expectedFinalByte = UInt8(1 + measuredPasses)
        let expectedChecksum = UInt64(BenchmarkWorkload.rawByteCount)
            * UInt64(measuredPasses * (measuredPasses + 3) / 2)
        precondition(iteration.checksum == expectedChecksum)
        precondition(buffer.withBytes { bytes in
            bytes.allSatisfy { $0 == expectedFinalByte }
        })

        return [append, iteration]
    }
}
