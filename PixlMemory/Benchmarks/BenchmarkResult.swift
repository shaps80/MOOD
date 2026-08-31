import Swift

struct BenchmarkResult {
    let name: String
    let operation: String
    let medianNanoseconds: Double
    let p95Nanoseconds: Double
    let maximumNanoseconds: Double
    let checksum: UInt64
}
