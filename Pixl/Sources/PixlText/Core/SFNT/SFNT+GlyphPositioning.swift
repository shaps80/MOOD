extension SFNT {
    struct GlyphPositioning {
        typealias Script = GlyphSubstitution.Script
        typealias Feature = GlyphSubstitution.Feature
        typealias LanguageSystem = GlyphSubstitution.LanguageSystem

        struct ValueAdjustment: Equatable {
            var xPlacement: Int16 = 0
            var yPlacement: Int16 = 0
            var xAdvance: Int16 = 0
            var yAdvance: Int16 = 0
        }

        struct PairRule {
            let first: UInt16
            let second: UInt16
            let firstAdjustment: ValueAdjustment
            let secondAdjustment: ValueAdjustment
        }

        struct ClassRange {
            let glyphs: ClosedRange<UInt16>
            let value: UInt16
        }

        struct ClassPairTable {
            let coverage: [UInt16]
            let firstClasses: [ClassRange]
            let secondClasses: [ClassRange]
            let firstClassCount: Int
            let secondClassCount: Int
            let firstAdjustments: [ValueAdjustment]
            let secondAdjustments: [ValueAdjustment]
        }

        enum PairSubtable {
            case glyphs([PairRule])
            case classes(ClassPairTable)
        }

        struct Lookup {
            let index: Int
            let pairs: [PairSubtable]
        }

        struct ActiveLookup {
            let lookup: Lookup
            let feature: UInt32
        }

        let scripts: [Script]
        let features: [Feature]
        let lookups: [Lookup]

        func activeLookups(script scriptTag: UInt32, language languageTag: UInt32?) -> [ActiveLookup] {
            guard let script = scripts.first(where: { $0.tag == scriptTag })
                    ?? scripts.first(where: { $0.tag == 0x4446_4C54 })
            else { return [] }
            let language = languageTag.flatMap { requested in
                script.languages.first(where: { $0.tag == requested })?.system
            } ?? script.defaultLanguage
            guard let language else { return [] }

            var featureIndices: [Int] = []
            if let required = language.requiredFeatureIndex { featureIndices.append(required) }
            featureIndices += language.featureIndices
            var tagsByLookup = Array<UInt32?>(repeating: nil, count: lookups.count)
            for featureIndex in featureIndices where features.indices.contains(featureIndex) {
                let feature = features[featureIndex]
                guard Self.isInitiallyEnabled(feature: feature.tag) else { continue }
                for lookupIndex in feature.lookupIndices
                    where tagsByLookup.indices.contains(lookupIndex) && tagsByLookup[lookupIndex] == nil {
                    tagsByLookup[lookupIndex] = feature.tag
                }
            }
            return lookups.compactMap { lookup in
                tagsByLookup[lookup.index].map { .init(lookup: lookup, feature: $0) }
            }
        }

        static func parse(table: Table, bytes: [UInt8]) throws -> Self {
            let reader = ByteReader(bytes)
            try require(table, at: table.offset, count: 10)
            let scriptListOffset = Int(try reader.uint16(at: table.offset + 4))
            let featureListOffset = Int(try reader.uint16(at: table.offset + 6))
            let lookupListOffset = Int(try reader.uint16(at: table.offset + 8))
            let scripts = try parseScripts(at: table.offset + scriptListOffset, table: table, reader: reader)
            let features = try parseFeatures(at: table.offset + featureListOffset, table: table, reader: reader)
            let lookupList = table.offset + lookupListOffset
            try require(table, at: lookupList, count: 2)
            let lookupCount = Int(try reader.uint16(at: lookupList))
            try require(table, at: lookupList + 2, count: lookupCount * 2)
            var lookups: [Lookup] = []
            for index in 0..<lookupCount {
                let lookup = lookupList + Int(try reader.uint16(at: lookupList + 2 + index * 2))
                try require(table, at: lookup, count: 6)
                let type = try reader.uint16(at: lookup)
                let count = Int(try reader.uint16(at: lookup + 4))
                try require(table, at: lookup + 6, count: count * 2)
                var pairs: [PairSubtable] = []
                for subtableIndex in 0..<count {
                    let subtable = lookup + Int(try reader.uint16(at: lookup + 6 + subtableIndex * 2))
                    if let parsed = try parsePairSubtable(type: type, at: subtable, table: table, reader: reader) {
                        pairs.append(parsed)
                    }
                }
                lookups.append(.init(index: index, pairs: pairs))
            }
            return .init(scripts: scripts, features: features, lookups: lookups)
        }

        private static func parsePairSubtable(
            type: UInt16,
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> PairSubtable? {
            if type == 9 {
                try require(table, at: offset, count: 8)
                guard try reader.uint16(at: offset) == 1 else { return nil }
                let extendedType = try reader.uint16(at: offset + 2)
                let extendedOffset = Int(try reader.uint32(at: offset + 4))
                guard extendedType != 9, extendedOffset > 0 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                return try parsePairSubtable(
                    type: extendedType,
                    at: offset + extendedOffset,
                    table: table,
                    reader: reader
                )
            }
            guard type == 2 else { return nil }
            try require(table, at: offset, count: 10)
            switch try reader.uint16(at: offset) {
            case 1: return try parseGlyphPairs(at: offset, table: table, reader: reader)
            case 2: return try parseClassPairs(at: offset, table: table, reader: reader)
            default: return nil
            }
        }

        private static func parseGlyphPairs(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> PairSubtable {
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            guard coverageOffset > 0 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let coverage = try coverageGlyphs(
                at: offset + coverageOffset,
                table: table,
                reader: reader
            )
            let firstFormat = try reader.uint16(at: offset + 4)
            let secondFormat = try reader.uint16(at: offset + 6)
            guard validValueFormat(firstFormat), validValueFormat(secondFormat) else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let setCount = Int(try reader.uint16(at: offset + 8))
            try require(table, at: offset + 10, count: setCount * 2)
            guard coverage.count == setCount else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            var rules: [PairRule] = []
            for setIndex in 0..<setCount {
                let setOffset = Int(try reader.uint16(at: offset + 10 + setIndex * 2))
                guard setOffset > 0 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                var cursor = offset + setOffset
                try require(table, at: cursor, count: 2)
                let pairCount = Int(try reader.uint16(at: cursor))
                cursor += 2
                for _ in 0..<pairCount {
                    try require(table, at: cursor, count: 2 + valueSize(firstFormat) + valueSize(secondFormat))
                    let second = try reader.uint16(at: cursor)
                    cursor += 2
                    let firstAdjustment = try value(at: &cursor, format: firstFormat, reader: reader)
                    let secondAdjustment = try value(at: &cursor, format: secondFormat, reader: reader)
                    rules.append(.init(
                        first: coverage[setIndex],
                        second: second,
                        firstAdjustment: firstAdjustment,
                        secondAdjustment: secondAdjustment
                    ))
                }
            }
            return .glyphs(rules)
        }

        private static func parseClassPairs(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> PairSubtable {
            try require(table, at: offset, count: 16)
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let firstClassOffset = Int(try reader.uint16(at: offset + 8))
            let secondClassOffset = Int(try reader.uint16(at: offset + 10))
            guard coverageOffset > 0, firstClassOffset > 0, secondClassOffset > 0 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let coverage = try coverageGlyphs(
                at: offset + coverageOffset,
                table: table,
                reader: reader
            )
            let firstFormat = try reader.uint16(at: offset + 4)
            let secondFormat = try reader.uint16(at: offset + 6)
            guard validValueFormat(firstFormat), validValueFormat(secondFormat) else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let firstClasses = try classRanges(
                at: offset + firstClassOffset,
                table: table,
                reader: reader
            )
            let secondClasses = try classRanges(
                at: offset + secondClassOffset,
                table: table,
                reader: reader
            )
            let firstCount = Int(try reader.uint16(at: offset + 12))
            let secondCount = Int(try reader.uint16(at: offset + 14))
            let recordSize = valueSize(firstFormat) + valueSize(secondFormat)
            guard recordSize > 0 else { return .glyphs([]) }
            let (recordCount, countOverflow) = firstCount.multipliedReportingOverflow(by: secondCount)
            let (byteCount, byteOverflow) = recordCount.multipliedReportingOverflow(by: recordSize)
            guard !countOverflow, !byteOverflow else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            try require(table, at: offset + 16, count: byteCount)
            var cursor = offset + 16
            var firstAdjustments: [ValueAdjustment] = []
            var secondAdjustments: [ValueAdjustment] = []
            firstAdjustments.reserveCapacity(recordCount)
            secondAdjustments.reserveCapacity(recordCount)
            for _ in 0..<recordCount {
                firstAdjustments.append(try value(at: &cursor, format: firstFormat, reader: reader))
                secondAdjustments.append(try value(at: &cursor, format: secondFormat, reader: reader))
            }
            return .classes(.init(
                coverage: coverage,
                firstClasses: firstClasses,
                secondClasses: secondClasses,
                firstClassCount: firstCount,
                secondClassCount: secondCount,
                firstAdjustments: firstAdjustments,
                secondAdjustments: secondAdjustments
            ))
        }

        private static func value(
            at cursor: inout Int,
            format: UInt16,
            reader: ByteReader
        ) throws -> ValueAdjustment {
            var result = ValueAdjustment()
            if format & 0x0001 != 0 { result.xPlacement = try reader.int16(at: cursor); cursor += 2 }
            if format & 0x0002 != 0 { result.yPlacement = try reader.int16(at: cursor); cursor += 2 }
            if format & 0x0004 != 0 { result.xAdvance = try reader.int16(at: cursor); cursor += 2 }
            if format & 0x0008 != 0 { result.yAdvance = try reader.int16(at: cursor); cursor += 2 }
            for bit in [UInt16(0x0010), 0x0020, 0x0040, 0x0080] where format & bit != 0 {
                _ = try reader.uint16(at: cursor)
                cursor += 2
            }
            return result
        }

        private static func valueSize(_ format: UInt16) -> Int {
            (format & 0x00FF).nonzeroBitCount * 2
        }

        private static func validValueFormat(_ format: UInt16) -> Bool {
            format & 0xFF00 == 0
        }

        private static func classRanges(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [ClassRange] {
            try require(table, at: offset, count: 4)
            switch try reader.uint16(at: offset) {
            case 1:
                try require(table, at: offset, count: 6)
                let start = try reader.uint16(at: offset + 2)
                let count = Int(try reader.uint16(at: offset + 4))
                try require(table, at: offset + 6, count: count * 2)
                guard Int(start) + count <= Int(UInt16.max) + 1 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                return try (0..<count).map { index in
                    let glyph = UInt16(truncatingIfNeeded: Int(start) + index)
                    return .init(
                        glyphs: glyph...glyph,
                        value: try reader.uint16(at: offset + 6 + index * 2)
                    )
                }
            case 2:
                let count = Int(try reader.uint16(at: offset + 2))
                try require(table, at: offset + 4, count: count * 6)
                var previousEnd: UInt16?
                return try (0..<count).map { index in
                    let record = offset + 4 + index * 6
                    let start = try reader.uint16(at: record)
                    let end = try reader.uint16(at: record + 2)
                    guard start <= end,
                          previousEnd.map({ $0 < start }) ?? true
                    else { throw SFNT.RegistrationError.malformedRequiredTable }
                    previousEnd = end
                    return .init(
                        glyphs: start...end,
                        value: try reader.uint16(at: record + 4)
                    )
                }
            default: return []
            }
        }

        private static func coverageGlyphs(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [UInt16] {
            try require(table, at: offset, count: 4)
            switch try reader.uint16(at: offset) {
            case 1:
                let count = Int(try reader.uint16(at: offset + 2))
                try require(table, at: offset + 4, count: count * 2)
                return try (0..<count).map { try reader.uint16(at: offset + 4 + $0 * 2) }
            case 2:
                let count = Int(try reader.uint16(at: offset + 2))
                try require(table, at: offset + 4, count: count * 6)
                var result: [UInt16] = []
                for index in 0..<count {
                    let record = offset + 4 + index * 6
                    let start = try reader.uint16(at: record)
                    let end = try reader.uint16(at: record + 2)
                    if start <= end { result.append(contentsOf: start...end) }
                }
                return result
            default: return []
            }
        }

        private static func parseScripts(
            at list: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [Script] {
            try require(table, at: list, count: 2)
            let count = Int(try reader.uint16(at: list))
            try require(table, at: list + 2, count: count * 6)
            return try (0..<count).map { index in
                let record = list + 2 + index * 6
                let script = list + Int(try reader.uint16(at: record + 4))
                try require(table, at: script, count: 4)
                let defaultOffset = Int(try reader.uint16(at: script))
                let languageCount = Int(try reader.uint16(at: script + 2))
                try require(table, at: script + 4, count: languageCount * 6)
                let defaultLanguage = defaultOffset == 0
                    ? nil
                    : try parseLanguage(at: script + defaultOffset, table: table, reader: reader)
                let languages = try (0..<languageCount).map { languageIndex in
                    let languageRecord = script + 4 + languageIndex * 6
                    return (
                        tag: try reader.uint32(at: languageRecord),
                        system: try parseLanguage(
                            at: script + Int(try reader.uint16(at: languageRecord + 4)),
                            table: table,
                            reader: reader
                        )
                    )
                }
                return .init(
                    tag: try reader.uint32(at: record),
                    defaultLanguage: defaultLanguage,
                    languages: languages
                )
            }
        }

        private static func parseLanguage(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> LanguageSystem {
            try require(table, at: offset, count: 6)
            let required = try reader.uint16(at: offset + 2)
            let count = Int(try reader.uint16(at: offset + 4))
            try require(table, at: offset + 6, count: count * 2)
            return .init(
                requiredFeatureIndex: required == 0xFFFF ? nil : Int(required),
                featureIndices: try (0..<count).map {
                    Int(try reader.uint16(at: offset + 6 + $0 * 2))
                }
            )
        }

        private static func parseFeatures(
            at list: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [Feature] {
            try require(table, at: list, count: 2)
            let count = Int(try reader.uint16(at: list))
            try require(table, at: list + 2, count: count * 6)
            return try (0..<count).map { index in
                let record = list + 2 + index * 6
                let feature = list + Int(try reader.uint16(at: record + 4))
                try require(table, at: feature, count: 4)
                let lookupCount = Int(try reader.uint16(at: feature + 2))
                try require(table, at: feature + 4, count: lookupCount * 2)
                return .init(
                    tag: try reader.uint32(at: record),
                    lookupIndices: try (0..<lookupCount).map {
                        Int(try reader.uint16(at: feature + 4 + $0 * 2))
                    }
                )
            }
        }

        private static func isInitiallyEnabled(feature: UInt32) -> Bool {
            feature == 0x6B65_726E || feature == 0x6469_7374 // kern, dist
        }

        private static func require(_ table: Table, at offset: Int, count: Int) throws {
            guard offset >= table.offset,
                  count >= 0,
                  offset <= table.offset + table.length - count
            else { throw SFNT.RegistrationError.malformedRequiredTable }
        }
    }
}
