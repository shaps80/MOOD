extension SFNT {
    struct DeltaSetIndexMap {
        struct Entry: Hashable {
            let outer: Int
            let inner: Int
        }

        let entries: [Entry]

        static func parse(at offset: Int, table: Table, reader: ByteReader) throws -> Self {
            try require(table, at: offset, count: 4)
            let format = try reader.uint8(at: offset)
            let entryFormat = try reader.uint8(at: offset + 1)
            let entrySize = Int((entryFormat >> 4) & 0x03) + 1
            let innerBitCount = Int(entryFormat & 0x0F) + 1
            let count: Int
            let entriesOffset: Int
            switch format {
            case 0:
                count = Int(try reader.uint16(at: offset + 2))
                entriesOffset = offset + 4
            case 1:
                try require(table, at: offset, count: 6)
                let rawCount = try reader.uint32(at: offset + 2)
                guard rawCount <= UInt32(Int.max) else {
                    throw RegistrationError.malformedRequiredTable
                }
                count = Int(rawCount)
                entriesOffset = offset + 6
            default:
                throw RegistrationError.malformedRequiredTable
            }
            try require(table, at: entriesOffset, count: try byteCount(count, entrySize))
            let innerMask = (UInt32(1) << UInt32(innerBitCount)) - 1
            var entries: [Entry] = []
            entries.reserveCapacity(count)
            for index in 0..<count {
                var value: UInt32 = 0
                for byte in 0..<entrySize {
                    value = value << 8 | UInt32(try reader.uint8(
                        at: entriesOffset + index * entrySize + byte
                    ))
                }
                entries.append(.init(
                    outer: Int(value >> UInt32(innerBitCount)),
                    inner: Int(value & innerMask)
                ))
            }
            return .init(entries: entries)
        }

        func entry(for index: Int) -> Entry {
            guard !entries.isEmpty else { return .init(outer: 0, inner: index) }
            return entries[min(max(index, 0), entries.count - 1)]
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
