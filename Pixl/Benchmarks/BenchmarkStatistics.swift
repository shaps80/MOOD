import Swift

struct BenchmarkStatistics {
    let median: Double
    let p95: Double
    let maximum: Double

    init(_ values: [Double]) {
        precondition(!values.isEmpty)
        let sorted = values.sorted()
        median = sorted[sorted.count / 2]
        p95 = sorted[Int(Double(sorted.count - 1) * 0.95)]
        maximum = sorted[sorted.count - 1]
    }
}
