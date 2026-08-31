import Swift

struct BenchmarkReport: CustomStringConvertible {
    let results: [BenchmarkResult]

    var description: String {
        let headings = ["Benchmark", "Unit", "Median", "p95", "Max"]
        let rows = results.map {
            [
                $0.name,
                $0.operation,
                format($0.medianNanoseconds),
                format($0.p95Nanoseconds),
                format($0.maximumNanoseconds)
            ]
        }
        var widths = headings.map(\.count)
        for row in rows {
            for index in row.indices {
                widths[index] = max(widths[index], row[index].count)
            }
        }
        let header = formatRow(headings, widths: widths, numeric: false)
        let separator = String(repeating: "─", count: header.count)
        let body = rows.map { formatRow($0, widths: widths, numeric: true) }
            .joined(separator: "\n")
        let checksum = results.reduce(UInt64(0)) { $0 &+ $1.checksum }
        return """
        PixlMemory benchmarks

        Warmups  \(BenchmarkRunner.warmupCount)
        Samples  \(BenchmarkRunner.sampleCount)

        \(header)
        \(separator)
        \(body)

        Checksum  \(checksum)
        """
    }

    private func format(_ value: Double) -> String {
        if value >= 1_000_000 {
            return format(value / 1_000_000, unit: "ms")
        }
        if value >= 1_000 {
            return format(value / 1_000, unit: "µs")
        }
        return format(value, unit: "ns")
    }

    private func format(_ value: Double, unit: String) -> String {
        let scaled = Int((value * 100).rounded())
        let whole = scaled / 100
        let fraction = scaled % 100
        return "\(whole).\(fraction < 10 ? "0" : "")\(fraction) \(unit)"
    }

    private func formatRow(
        _ columns: [String],
        widths: [Int],
        numeric: Bool
    ) -> String {
        columns.indices.map { index in
            let value = columns[index]
            let padding = String(
                repeating: " ",
                count: widths[index] - value.count
            )
            return numeric && index >= 2 ? padding + value : value + padding
        }.joined(separator: "  ")
    }
}
