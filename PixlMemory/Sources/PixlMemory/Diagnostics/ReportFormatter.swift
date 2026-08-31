import Swift

enum ReportFormatter {
    static func startup(_ arena: ArenaStorage) -> String {
        let maximum = max(arena.reserved, arena.layoutOrder.map(\.required).max() ?? 0)
        let unit = Unit.select(maximum)
        let persistent = table(
            headings: ["Persistent", "Required"],
            rows: [[arena.persistentRecord.name, unit.format(arena.persistentRecord.required)]]
        )
        let layouts = table(
            headings: ["Layouts", "Required"],
            rows: arena.layoutOrder.map { [$0.name, unit.format($0.required)] }
        )
        let reserved = alignRows([["Reserved", unit.format(arena.reserved)]])
        return """
        \(arena.name ?? "Arena"): startup

        \(persistent)

        \(layouts)

        \(reserved)
        """ + "\n"
    }

    static func acquired(_ scope: ScopeStorage) -> String {
        let unit = Unit.select(scope.layout.required)
        let rows = layoutRows(scope.layout, unit: unit)
        return """
        \(scope.arena?.name ?? "Arena"): acquired \(scope.layout.name)

        \(table(headings: ["Layout / Region", "Required"], rows: rows))
        """ + "\n"
    }

    static func peak(_ arena: ArenaStorage) -> String {
        let unit = Unit.select(arena.reserved)
        var rows: [[String]] = []
        rows += peakRows(
            arena.persistentRecord,
            scopes: arena.history.filter { $0.layout.typeID == arena.persistentRecord.typeID && $0.placement == 0 },
            unit: unit
        )
        for layout in arena.layoutOrder {
            if !rows.isEmpty { rows.append(["", "", ""]) }
            rows += peakRows(
                layout,
                scopes: arena.history.filter { $0.layout.typeID == layout.typeID && $0.placement != 0 },
                unit: unit
            )
        }
        let body = table(
            headings: ["Layout / Region", "Reserved", "Peak"],
            rows: rows,
            includeSeparator: true
        )
        let total = alignRows([[
            "Arena",
            unit.format(arena.reserved),
            unit.format(arena.peak)
        ]], widthsFrom: ["Layout / Region", "Reserved", "Peak"] + rows.flatMap { $0 })
        return """
        \(arena.name ?? "Arena"): peak usage

        \(body)

        \(total)
        """ + "\n"
    }

    static func failure(arenaName: String?, title: String, details: [(String, String)]) -> String {
        let details = details.compactMap { label, value -> (String, String)? in
            guard !value.isEmpty else { return nil }
            return (label == "Location" ? "Access" : label, value)
        }
        let width = details.map { $0.0.count }.max() ?? 0
        let source = Set(["Reservation", "Access"])
        var lines: [String] = []
        for (index, detail) in details.enumerated() {
            if index > 0 {
                let previous = details[index - 1].0
                let startsSourceSection = source.contains(detail.0) && !source.contains(previous)
                if previous == "Region" || startsSourceSection || detail.0 == "Fix" {
                    lines.append("")
                }
            }
            lines.append(
                detail.0
                    + String(repeating: " ", count: width - detail.0.count + 2)
                    + detail.1
            )
        }
        let body = lines.joined(separator: "\n")
        return """
        \(arenaName ?? "Arena"): failure

        \(title)

        \(body)
        """ + "\n"
    }

    static func bytes(_ value: UInt64) -> String {
        Unit.select(value).format(value)
    }

    private static func layoutRows(_ layout: LayoutRecord, unit: Unit, prefix: String = "") -> [[String]] {
        var rows = [[prefix + layout.name, unit.format(layout.required)]]
        for (index, entry) in layout.entries.enumerated() {
            let last = index == layout.entries.count - 1
            let branch = last ? "└── " : "├── "
            let continuation = last ? "    " : "│   "
            switch entry {
            case .region(let region):
                rows.append([prefix + branch + displayName(region.name), unit.format(region.payload)])
            case .child(let child):
                let childRows = layoutRows(child.layout, unit: unit, prefix: prefix + continuation)
                if let first = childRows.first {
                    rows.append([prefix + branch + first[0].dropFirst((prefix + continuation).count), first[1]])
                    rows.append(contentsOf: childRows.dropFirst())
                }
            }
        }
        return rows
    }

    private static func peakRows(_ layout: LayoutRecord, scopes: [ScopeStorage], unit: Unit, prefix: String = "") -> [[String]] {
        let layoutPeak = scopes.map(\.peakUsed).max() ?? 0
        var rows = [[prefix + layout.name, unit.format(layout.required), unit.format(layoutPeak)]]
        for (index, entry) in layout.entries.enumerated() {
            let last = index == layout.entries.count - 1
            let branch = last ? "└── " : "├── "
            switch entry {
            case .region(let region):
                let peak = scopes.compactMap { $0.regions[region.name]?.peakBytes }.max() ?? 0
                rows.append([prefix + branch + displayName(region.name), unit.format(region.payload), unit.format(peak)])
            case .child(let child):
                let children = scopes.flatMap { parent in
                    parent.arena?.history.filter { $0.parent === parent && $0.layout.typeID == child.layout.typeID } ?? []
                }
                let nested = peakRows(child.layout, scopes: children, unit: unit, prefix: prefix + (last ? "    " : "│   "))
                if let first = nested.first {
                    rows.append([prefix + branch + child.layout.name, first[1], first[2]])
                    rows.append(contentsOf: nested.dropFirst())
                }
            }
        }
        return rows
    }

    private static func displayName(_ identifier: String) -> String {
        guard let first = identifier.first else { return identifier }
        return first.uppercased() + identifier.dropFirst()
    }

    private static func table(headings: [String], rows: [[String]], includeSeparator: Bool = true) -> String {
        var widths = headings.map(\.count)
        for row in rows where row.count == headings.count {
            for index in row.indices { widths[index] = max(widths[index], row[index].count) }
        }
        let header = format(headings, widths: widths, numeric: false)
        let separator = String(repeating: "─", count: header.count)
        let body = rows.map { row in
            row.allSatisfy(\.isEmpty) ? "" : format(row, widths: widths, numeric: true)
        }
        return ([header] + (includeSeparator ? [separator] : []) + body).joined(separator: "\n")
    }

    private static func alignRows(_ rows: [[String]], widthsFrom values: [String] = []) -> String {
        guard let count = rows.first?.count else { return "" }
        var widths = Array(repeating: 0, count: count)
        for row in rows {
            for index in row.indices { widths[index] = max(widths[index], row[index].count) }
        }
        if !values.isEmpty, count > 0 {
            widths[0] = max(widths[0], values.filter { !$0.contains(".") }.map(\.count).max() ?? 0)
        }
        return rows.map { format($0, widths: widths, numeric: true) }.joined(separator: "\n")
    }

    private static func format(_ columns: [String], widths: [Int], numeric: Bool) -> String {
        columns.indices.map { index in
            let value = columns[index]
            let padding = String(repeating: " ", count: max(0, widths[index] - value.count))
            return index > 0 && numeric ? padding + value : value + padding
        }.joined(separator: "  ")
    }
}

private enum Unit {
    case bytes, kilobytes, megabytes

    static func select(_ maximum: UInt64) -> Self {
        if maximum >= 1_000_000 { return .megabytes }
        if maximum >= 1_000 { return .kilobytes }
        return .bytes
    }

    func format(_ value: UInt64) -> String {
        if value == 0 { return "0 bytes" }
        let divisor: UInt64
        let suffix: String
        switch self {
        case .bytes: divisor = 1; suffix = "bytes"
        case .kilobytes: divisor = 1_000; suffix = "KB"
        case .megabytes: divisor = 1_000_000; suffix = "MB"
        }
        var whole = value / divisor
        let remainder = value % divisor
        var fraction = (remainder * 100 + divisor / 2) / divisor
        if fraction == 100 { whole += 1; fraction = 0 }
        let digits = fraction < 10 ? "0\(fraction)" : "\(fraction)"
        return "\(whole).\(digits) \(suffix)"
    }
}
