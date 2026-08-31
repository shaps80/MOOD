import Swift

enum ReportFormatter {
    static func startup(arena: Arena) -> String {
        let plans = [arena.permanentPlan].compactMap { $0 } + arena.plans
        guard !plans.isEmpty else {
            return """
            PixlMemory startup

            Concurrency: \(arena.concurrency.reportDescription)

            Reserved: 0 bytes
            """
        }
        let maximum = max(
            arena.reserved.rawValue,
            plans.map(\.required.rawValue).max() ?? 0
        )
        let unit = Unit.select(for: maximum)
        let rows = plans.map { ($0.name, unit.format($0.required)) }
        return """
        PixlMemory startup

        Concurrency: \(arena.concurrency.reportDescription)

        \(table(first: "Plan", second: "Required", rows: rows, total: ("Reserved", unit.format(arena.reserved))))
        """
    }

    static func peak(arena: Arena, scopes: [Scope]) -> String {
        let rows = scopes.map { scope in
            let statistics = scope.statistics
            return PeakRow(
                name: scope.name,
                reserved: statistics.reserved,
                peak: statistics.peak,
                unused: statistics.unused
            )
        }
        let maximum = max(
            arena.reserved.rawValue,
            rows.flatMap { [
                $0.reserved.rawValue,
                $0.peak.rawValue,
                $0.unused.rawValue
            ] }.max() ?? 0
        )
        let unit = Unit.select(for: maximum)
        let formatted = rows.map {
            [
                $0.name,
                unit.format($0.reserved),
                unit.format($0.peak),
                unit.format($0.unused)
            ]
        }
        let arenaStatistics = arena.statistics
        return """
        PixlMemory peak usage

        \(table(
            headings: ["Scope", "Reserved", "Peak", "Unused"],
            rows: formatted,
            total: [
                "Total",
                unit.format(arenaStatistics.reserved),
                unit.format(arenaStatistics.peak),
                unit.format(arenaStatistics.unused)
            ]
        ))
        """
    }

    static func plan(_ plan: MemoryPlan) -> String {
        let maximum = max(
            plan.required.rawValue,
            plan.definitions.map(\.payload.rawValue).max() ?? 0
        )
        let unit = Unit.select(for: maximum)
        let rows = plan.definitions.map {
            ($0.name, unit.format($0.payload))
        }
        return """
        PixlMemory plan: \(plan.name)

        \(table(first: "Reservation", second: "Required", rows: rows, total: ("Required", unit.format(plan.required))))

        Payload: \(unit.format(plan.payload))
        Padding: \(unit.format(plan.padding))
        """
    }

    static func scope(_ scope: Scope) -> String {
        let statistics = scope.statistics
        let unit = Unit.select(for: statistics.reserved.rawValue)
        return """
        PixlMemory scope: \(scope.name)

        Reserved: \(unit.format(statistics.reserved))
        Used:     \(unit.format(statistics.used))
        Peak:     \(unit.format(statistics.peak))
        Unused:   \(unit.format(statistics.unused))
        """
    }

    private static func table(
        first: String,
        second: String,
        rows: [(String, String)],
        total: (String, String)
    ) -> String {
        table(
            headings: [first, second],
            rows: rows.map { [$0.0, $0.1] },
            total: [total.0, total.1]
        )
    }

    private static func table(
        headings: [String],
        rows: [[String]],
        total: [String]
    ) -> String {
        var widths = headings.map(\.count)
        for row in rows + [total] {
            for index in row.indices {
                widths[index] = max(widths[index], row[index].count)
            }
        }
        let header = format(headings, widths: widths, numeric: false)
        let separator = String(repeating: "─", count: header.count)
        let body = rows.map { format($0, widths: widths, numeric: true) }
        return ([header, separator] + body + [separator, format(total, widths: widths, numeric: true)])
            .joined(separator: "\n")
    }

    private static func format(
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
            if index > 0 && numeric {
                return padding + value
            }
            return value + padding
        }.joined(separator: "  ")
    }
}

private struct PeakRow {
    let name: String
    let reserved: ByteCount
    let peak: ByteCount
    let unused: ByteCount
}

private enum Unit {
    case bytes
    case kilobytes
    case megabytes

    static func select(for maximum: UInt64) -> Self {
        if maximum >= 1_000_000 { return .megabytes }
        if maximum >= 1_000 { return .kilobytes }
        return .bytes
    }

    func format(_ bytes: ByteCount) -> String {
        let divisor: UInt64
        let suffix: String
        switch self {
        case .bytes:
            divisor = 1
            suffix = "bytes"
        case .kilobytes:
            divisor = 1_000
            suffix = "KB"
        case .megabytes:
            divisor = 1_000_000
            suffix = "MB"
        }

        var whole = bytes.rawValue / divisor
        let remainder = bytes.rawValue % divisor
        var fraction = (remainder * 100 + divisor / 2) / divisor
        if fraction == 100 {
            whole += 1
            fraction = 0
        }
        let fractionText = fraction < 10 ? "0\(fraction)" : "\(fraction)"
        return "\(whole).\(fractionText) \(suffix)"
    }
}
