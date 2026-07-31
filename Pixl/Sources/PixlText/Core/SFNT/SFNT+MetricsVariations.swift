extension SFNT {
    struct MetricsVariations {
        struct MetricRecord: Hashable {
            let tag: UInt32
            let outer: Int
            let inner: Int
        }

        let horizontalStore: ItemVariationStore?
        let horizontalAdvanceMap: DeltaSetIndexMap?
        let verticalStore: ItemVariationStore?
        let verticalAdvanceMap: DeltaSetIndexMap?
        let globalStore: ItemVariationStore?
        let globalRecords: [MetricRecord]

        static func parse(
            hvar: Table?,
            vvar: Table?,
            mvar: Table?,
            bytes: [UInt8]
        ) throws -> Self? {
            let reader = ByteReader(bytes)
            let horizontal = try hvar.map { try parseAdvanceTable($0, reader: reader) }
            let vertical = try vvar.map { try parseAdvanceTable($0, reader: reader) }
            let global = try mvar.map { try parseGlobalTable($0, reader: reader) }
            guard horizontal != nil || vertical != nil || global != nil else { return nil }
            return .init(
                horizontalStore: horizontal?.store,
                horizontalAdvanceMap: horizontal?.map,
                verticalStore: vertical?.store,
                verticalAdvanceMap: vertical?.map,
                globalStore: global?.store,
                globalRecords: global?.records ?? []
            )
        }

        func horizontalAdvanceDelta(glyph: Int, coordinates: [Float]) -> Float {
            guard let horizontalStore else { return 0 }
            let entry = horizontalAdvanceMap?.entry(for: glyph)
                ?? .init(outer: 0, inner: glyph)
            return horizontalStore.delta(
                outer: entry.outer,
                inner: entry.inner,
                coordinates: coordinates
            )
        }

        func verticalAdvanceDelta(glyph: Int, coordinates: [Float]) -> Float {
            guard let verticalStore else { return 0 }
            let entry = verticalAdvanceMap?.entry(for: glyph)
                ?? .init(outer: 0, inner: glyph)
            return verticalStore.delta(
                outer: entry.outer,
                inner: entry.inner,
                coordinates: coordinates
            )
        }

        func globalDelta(tag: UInt32, coordinates: [Float]) -> Float {
            guard let globalStore,
                  let record = globalRecords.first(where: { $0.tag == tag })
            else { return 0 }
            return globalStore.delta(
                outer: record.outer,
                inner: record.inner,
                coordinates: coordinates
            )
        }

        private static func parseAdvanceTable(
            _ table: Table,
            reader: ByteReader
        ) throws -> (store: ItemVariationStore, map: DeltaSetIndexMap?) {
            try require(table, at: table.offset, count: 20)
            guard try reader.uint16(at: table.offset) == 1 else {
                throw RegistrationError.malformedRequiredTable
            }
            let storeOffset = Int(try reader.uint32(at: table.offset + 4))
            guard storeOffset != 0 else { throw RegistrationError.malformedRequiredTable }
            let mapOffset = Int(try reader.uint32(at: table.offset + 8))
            return (
                try ItemVariationStore.parse(
                    at: table.offset + storeOffset,
                    table: table,
                    reader: reader
                ),
                mapOffset == 0 ? nil : try DeltaSetIndexMap.parse(
                    at: table.offset + mapOffset,
                    table: table,
                    reader: reader
                )
            )
        }

        private static func parseGlobalTable(
            _ table: Table,
            reader: ByteReader
        ) throws -> (store: ItemVariationStore, records: [MetricRecord]) {
            try require(table, at: table.offset, count: 12)
            guard try reader.uint16(at: table.offset) == 1 else {
                throw RegistrationError.malformedRequiredTable
            }
            let recordSize = Int(try reader.uint16(at: table.offset + 6))
            let recordCount = Int(try reader.uint16(at: table.offset + 8))
            let storeOffset = Int(try reader.uint16(at: table.offset + 10))
            guard recordSize >= 8, storeOffset != 0 else {
                throw RegistrationError.malformedRequiredTable
            }
            try require(table, at: table.offset + 12, count: try byteCount(recordCount, recordSize))
            var records: [MetricRecord] = []
            records.reserveCapacity(recordCount)
            for index in 0..<recordCount {
                let offset = table.offset + 12 + index * recordSize
                records.append(.init(
                    tag: try reader.uint32(at: offset),
                    outer: Int(try reader.uint16(at: offset + 4)),
                    inner: Int(try reader.uint16(at: offset + 6))
                ))
            }
            return (
                try ItemVariationStore.parse(
                    at: table.offset + storeOffset,
                    table: table,
                    reader: reader
                ),
                records
            )
        }

        private static func require(_ table: Table, at offset: Int, count: Int) throws {
            guard offset >= table.offset, count >= 0,
                  offset <= table.offset + table.length - count
            else { throw RegistrationError.malformedRequiredTable }
        }

        private static func byteCount(_ lhs: Int, _ rhs: Int) throws -> Int {
            let result = lhs.multipliedReportingOverflow(by: rhs)
            guard !result.overflow else { throw RegistrationError.malformedRequiredTable }
            return result.partialValue
        }
    }
}
