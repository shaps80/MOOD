extension SFNT {
    struct GlyphSubstitution {
        struct Lookup {
            let index: Int
            let feature: UInt32
            let substitutions: [Substitution]
        }

        enum Substitution {
            case single(input: UInt16, output: UInt16)
            case ligature(components: [UInt16], output: UInt16)
        }

        let lookups: [Lookup]

        static func parse(table: Table, bytes: [UInt8]) throws -> Self {
            let reader = ByteReader(bytes)
            try require(table, relativeOffset: 0, count: 10)
            let featureListOffset = Int(try reader.uint16(at: table.offset + 6))
            let lookupListOffset = Int(try reader.uint16(at: table.offset + 8))
            let lookupList = table.offset + lookupListOffset
            try require(table, absoluteOffset: lookupList, count: 2)
            let lookupCount = Int(try reader.uint16(at: lookupList))
            try require(table, absoluteOffset: lookupList + 2, count: lookupCount * 2)

            let features = try featureTagsByLookup(
                table: table,
                featureListOffset: featureListOffset,
                lookupCount: lookupCount,
                reader: reader
            )

            var lookups: [Lookup] = []
            for lookupIndex in 0..<lookupCount {
                guard let feature = features[lookupIndex] else { continue }
                let relativeOffset = Int(try reader.uint16(at: lookupList + 2 + lookupIndex * 2))
                let lookup = lookupList + relativeOffset
                try require(table, absoluteOffset: lookup, count: 6)
                let type = try reader.uint16(at: lookup)
                let subtableCount = Int(try reader.uint16(at: lookup + 4))
                try require(table, absoluteOffset: lookup + 6, count: subtableCount * 2)

                var substitutions: [Substitution] = []
                for subtableIndex in 0..<subtableCount {
                    let subtableOffset = Int(try reader.uint16(at: lookup + 6 + subtableIndex * 2))
                    let subtable = lookup + subtableOffset
                    substitutions += try parseSubtable(
                        type: type,
                        offset: subtable,
                        table: table,
                        reader: reader
                    )
                }
                if !substitutions.isEmpty {
                    lookups.append(.init(
                        index: lookupIndex,
                        feature: feature,
                        substitutions: substitutions
                    ))
                }
            }
            return .init(lookups: lookups)
        }

        private static func featureTagsByLookup(
            table: Table,
            featureListOffset: Int,
            lookupCount: Int,
            reader: ByteReader
        ) throws -> [UInt32?] {
            let featureList = table.offset + featureListOffset
            try require(table, absoluteOffset: featureList, count: 2)
            let featureCount = Int(try reader.uint16(at: featureList))
            try require(table, absoluteOffset: featureList + 2, count: featureCount * 6)
            var result = Array<UInt32?>(repeating: nil, count: lookupCount)

            for index in 0..<featureCount {
                let record = featureList + 2 + index * 6
                let tag = try reader.uint32(at: record)
                guard isInitiallyEnabled(feature: tag) else { continue }
                let feature = featureList + Int(try reader.uint16(at: record + 4))
                try require(table, absoluteOffset: feature, count: 4)
                let count = Int(try reader.uint16(at: feature + 2))
                try require(table, absoluteOffset: feature + 4, count: count * 2)
                for lookupIndex in 0..<count {
                    let value = Int(try reader.uint16(at: feature + 4 + lookupIndex * 2))
                    guard result.indices.contains(value) else { continue }
                    if result[value] == nil {
                        result[value] = tag
                    }
                }
            }
            return result
        }

        private static func parseSubtable(
            type: UInt16,
            offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [Substitution] {
            if type == 7 {
                try require(table, absoluteOffset: offset, count: 8)
                guard try reader.uint16(at: offset) == 1 else { return [] }
                let extendedType = try reader.uint16(at: offset + 2)
                let extendedOffset = Int(try reader.uint32(at: offset + 4))
                return try parseSubtable(
                    type: extendedType,
                    offset: offset + extendedOffset,
                    table: table,
                    reader: reader
                )
            }

            switch type {
            case 1:
                return try parseSingleSubstitution(at: offset, table: table, reader: reader)
            case 4:
                return try parseLigatureSubstitution(at: offset, table: table, reader: reader)
            default:
                return []
            }
        }

        private static func parseSingleSubstitution(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [Substitution] {
            try require(table, absoluteOffset: offset, count: 6)
            let format = try reader.uint16(at: offset)
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let coverage = try coverageGlyphs(at: offset + coverageOffset, table: table, reader: reader)

            switch format {
            case 1:
                let delta = try reader.int16(at: offset + 4)
                return coverage.map {
                    .single(input: $0, output: UInt16(truncatingIfNeeded: Int($0) + Int(delta)))
                }
            case 2:
                let count = Int(try reader.uint16(at: offset + 4))
                try require(table, absoluteOffset: offset + 6, count: count * 2)
                guard count == coverage.count else { return [] }
                return try coverage.enumerated().map { index, glyph in
                    .single(input: glyph, output: try reader.uint16(at: offset + 6 + index * 2))
                }
            default:
                return []
            }
        }

        private static func parseLigatureSubstitution(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [Substitution] {
            try require(table, absoluteOffset: offset, count: 6)
            guard try reader.uint16(at: offset) == 1 else { return [] }
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let firstGlyphs = try coverageGlyphs(
                at: offset + coverageOffset,
                table: table,
                reader: reader
            )
            let setCount = Int(try reader.uint16(at: offset + 4))
            try require(table, absoluteOffset: offset + 6, count: setCount * 2)
            guard setCount == firstGlyphs.count else { return [] }

            var result: [Substitution] = []
            for setIndex in 0..<setCount {
                let set = offset + Int(try reader.uint16(at: offset + 6 + setIndex * 2))
                try require(table, absoluteOffset: set, count: 2)
                let ligatureCount = Int(try reader.uint16(at: set))
                try require(table, absoluteOffset: set + 2, count: ligatureCount * 2)
                for ligatureIndex in 0..<ligatureCount {
                    let ligature = set + Int(try reader.uint16(at: set + 2 + ligatureIndex * 2))
                    try require(table, absoluteOffset: ligature, count: 4)
                    let output = try reader.uint16(at: ligature)
                    let componentCount = Int(try reader.uint16(at: ligature + 2))
                    guard componentCount > 0 else { continue }
                    try require(
                        table,
                        absoluteOffset: ligature + 4,
                        count: (componentCount - 1) * 2
                    )
                    var components = [firstGlyphs[setIndex]]
                    for componentIndex in 0..<(componentCount - 1) {
                        components.append(try reader.uint16(
                            at: ligature + 4 + componentIndex * 2
                        ))
                    }
                    result.append(.ligature(components: components, output: output))
                }
            }
            return result
        }

        private static func coverageGlyphs(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [UInt16] {
            try require(table, absoluteOffset: offset, count: 4)
            switch try reader.uint16(at: offset) {
            case 1:
                let count = Int(try reader.uint16(at: offset + 2))
                try require(table, absoluteOffset: offset + 4, count: count * 2)
                return try (0..<count).map { try reader.uint16(at: offset + 4 + $0 * 2) }
            case 2:
                let count = Int(try reader.uint16(at: offset + 2))
                try require(table, absoluteOffset: offset + 4, count: count * 6)
                var glyphs: [UInt16] = []
                for index in 0..<count {
                    let record = offset + 4 + index * 6
                    let start = try reader.uint16(at: record)
                    let end = try reader.uint16(at: record + 2)
                    guard start <= end else { continue }
                    glyphs += start...end
                }
                return glyphs
            default:
                return []
            }
        }

        private static func isInitiallyEnabled(feature: UInt32) -> Bool {
            switch feature {
            case 0x6363_6D70, // ccmp
                 0x6C6F_636C, // locl
                 0x726C_6967, // rlig
                 0x6C69_6761, // liga
                 0x636C_6967, // clig
                 0x6361_6C74: // calt
                true
            default:
                false
            }
        }

        private static func require(
            _ table: Table,
            relativeOffset: Int,
            count: Int
        ) throws {
            try require(
                table,
                absoluteOffset: table.offset + relativeOffset,
                count: count
            )
        }

        private static func require(
            _ table: Table,
            absoluteOffset: Int,
            count: Int
        ) throws {
            guard absoluteOffset >= table.offset,
                  count >= 0,
                  absoluteOffset <= table.offset + table.length - count
            else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
        }
    }
}
