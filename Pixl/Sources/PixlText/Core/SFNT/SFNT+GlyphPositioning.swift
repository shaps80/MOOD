extension SFNT {
    struct GlyphPositioning {
        typealias Script = GlyphSubstitution.Script
        typealias Feature = GlyphSubstitution.Feature
        typealias LanguageSystem = GlyphSubstitution.LanguageSystem

        struct ValueAdjustment: Equatable {
            var xPlacement: Int32 = 0
            var yPlacement: Int32 = 0
            var xAdvance: Int32 = 0
            var yAdvance: Int32 = 0
            var xPlacementVariation: OpenTypeLayout.VariationIndex?
            var yPlacementVariation: OpenTypeLayout.VariationIndex?
            var xAdvanceVariation: OpenTypeLayout.VariationIndex?
            var yAdvanceVariation: OpenTypeLayout.VariationIndex?

            func resolved(
                store: ItemVariationStore?,
                coordinates: [Float]
            ) -> Self {
                guard let store else { return self }
                var result = self
                result.xPlacement += delta(xPlacementVariation, store, coordinates)
                result.yPlacement += delta(yPlacementVariation, store, coordinates)
                result.xAdvance += delta(xAdvanceVariation, store, coordinates)
                result.yAdvance += delta(yAdvanceVariation, store, coordinates)
                result.xPlacementVariation = nil
                result.yPlacementVariation = nil
                result.xAdvanceVariation = nil
                result.yAdvanceVariation = nil
                return result
            }

            private func delta(
                _ index: OpenTypeLayout.VariationIndex?,
                _ store: ItemVariationStore,
                _ coordinates: [Float]
            ) -> Int32 {
                guard let index else { return 0 }
                return Int32(store.delta(
                    outer: index.outer,
                    inner: index.inner,
                    coordinates: coordinates
                ).rounded())
            }
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

        struct SingleRule {
            let glyph: UInt16
            let adjustment: ValueAdjustment
        }

        struct CursiveRecord {
            let glyph: UInt16
            let entry: OpenTypeLayout.Anchor?
            let exit: OpenTypeLayout.Anchor?
        }

        struct MarkRecord {
            let glyph: UInt16
            let markClass: UInt16
            let anchor: OpenTypeLayout.Anchor
        }

        struct BaseRecord {
            let glyph: UInt16
            let anchors: [OpenTypeLayout.Anchor?]
        }

        struct LigatureRecord {
            let glyph: UInt16
            let components: [[OpenTypeLayout.Anchor?]]
        }

        struct MarkToBaseTable {
            let marks: [MarkRecord]
            let bases: [BaseRecord]
            let classCount: Int
        }

        struct MarkToLigatureTable {
            let marks: [MarkRecord]
            let ligatures: [LigatureRecord]
            let classCount: Int
        }

        enum Subtable {
            case single([SingleRule])
            case pair(PairSubtable)
            case cursive([CursiveRecord])
            case markToBase(MarkToBaseTable)
            case markToLigature(MarkToLigatureTable)
            case markToMark(MarkToBaseTable)
            case context(OpenTypeLayout.ContextRule)
        }

        struct Lookup {
            let index: Int
            let flags: OpenTypeLayout.LookupFlags
            let subtables: [Subtable]

            init(
                index: Int,
                flags: OpenTypeLayout.LookupFlags = .init(rawValue: 0, markFilteringSet: nil),
                subtables: [Subtable]
            ) {
                self.index = index
                self.flags = flags
                self.subtables = subtables
            }

            init(index: Int, pairs: [PairSubtable]) {
                self.init(
                    index: index,
                    subtables: pairs.map(Subtable.pair)
                )
            }
        }

        struct ActiveLookup {
            let lookup: Lookup
            let feature: UInt32
        }

        let scripts: [Script]
        let features: [Feature]
        let lookups: [Lookup]
        let featureVariations: OpenTypeFeatureVariations?

        func activeLookups(
            script scriptTag: UInt32,
            language languageTag: UInt32?,
            coordinates: [Float]
        ) -> [ActiveLookup] {
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
            let substitutions = featureVariations?.substitutions(coordinates: coordinates) ?? []
            var tagsByLookup = Array<UInt32?>(repeating: nil, count: lookups.count)
            for featureIndex in featureIndices where features.indices.contains(featureIndex) {
                let feature = features[featureIndex]
                guard Self.isInitiallyEnabled(feature: feature.tag) else { continue }
                let alternate = substitutions
                    .first(where: { $0.featureIndex == featureIndex })?.lookupIndices
                for lookupIndex in alternate ?? feature.lookupIndices
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
            let majorVersion = try reader.uint16(at: table.offset)
            let minorVersion = try reader.uint16(at: table.offset + 2)
            guard majorVersion == 1, minorVersion == 0 || minorVersion == 1 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            var featureVariationsOffset = 0
            if minorVersion == 1 {
                try require(table, at: table.offset, count: 14)
                featureVariationsOffset = Int(try reader.uint32(at: table.offset + 10))
            }
            let scriptListOffset = Int(try reader.uint16(at: table.offset + 4))
            let featureListOffset = Int(try reader.uint16(at: table.offset + 6))
            let lookupListOffset = Int(try reader.uint16(at: table.offset + 8))
            let scripts = try parseScripts(at: table.offset + scriptListOffset, table: table, reader: reader)
            let features = try parseFeatures(at: table.offset + featureListOffset, table: table, reader: reader)
            let featureVariations = featureVariationsOffset == 0 ? nil
                : try OpenTypeFeatureVariations.parse(
                    at: table.offset + featureVariationsOffset,
                    table: table,
                    featureCount: features.count,
                    reader: reader
                )
            guard lookupListOffset != 0 else {
                try OpenTypeLayout.validateReferences(
                    scripts: scripts,
                    features: features,
                    lookupCount: 0
                )
                try featureVariations?.validate(lookupCount: 0)
                return .init(
                    scripts: scripts,
                    features: features,
                    lookups: [],
                    featureVariations: featureVariations
                )
            }
            let lookupList = table.offset + lookupListOffset
            try require(table, at: lookupList, count: 2)
            let lookupCount = Int(try reader.uint16(at: lookupList))
            try require(table, at: lookupList + 2, count: lookupCount * 2)
            var lookups: [Lookup] = []
            for index in 0..<lookupCount {
                let lookup = lookupList + Int(try reader.uint16(at: lookupList + 2 + index * 2))
                try require(table, at: lookup, count: 6)
                let type = try reader.uint16(at: lookup)
                let rawFlags = try reader.uint16(at: lookup + 2)
                guard rawFlags & 0x00E0 == 0 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                let count = Int(try reader.uint16(at: lookup + 4))
                try require(table, at: lookup + 6, count: count * 2)
                let markFilteringSet: UInt16?
                if rawFlags & 0x0010 != 0 {
                    try require(table, at: lookup + 6 + count * 2, count: 2)
                    markFilteringSet = try reader.uint16(at: lookup + 6 + count * 2)
                } else {
                    markFilteringSet = nil
                }
                var subtables: [Subtable] = []
                for subtableIndex in 0..<count {
                    let relativeOffset = Int(try reader.uint16(at: lookup + 6 + subtableIndex * 2))
                    guard relativeOffset > 0 else {
                        throw SFNT.RegistrationError.malformedRequiredTable
                    }
                    subtables += try parseSubtable(
                        type: type,
                        at: lookup + relativeOffset,
                        table: table,
                        reader: reader,
                        lookupCount: lookupCount
                    )
                }
                lookups.append(.init(
                    index: index,
                    flags: .init(rawValue: rawFlags, markFilteringSet: markFilteringSet),
                    subtables: subtables
                ))
            }
            try OpenTypeLayout.validateReferences(
                scripts: scripts,
                features: features,
                lookupCount: lookups.count
            )
            try featureVariations?.validate(lookupCount: lookups.count)
            return .init(
                scripts: scripts,
                features: features,
                lookups: lookups,
                featureVariations: featureVariations
            )
        }

        private static func parseSubtable(
            type: UInt16,
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [Subtable] {
            if type == 9 {
                try require(table, at: offset, count: 8)
                guard try reader.uint16(at: offset) == 1 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                let extendedType = try reader.uint16(at: offset + 2)
                let extendedOffset = Int(try reader.uint32(at: offset + 4))
                guard extendedType != 9, extendedOffset > 0 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                return try parseSubtable(
                    type: extendedType,
                    at: offset + extendedOffset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                )
            }
            switch type {
            case 1:
                return [.single(try parseSingleAdjustments(
                    at: offset,
                    table: table,
                    reader: reader
                ))]
            case 2:
                try require(table, at: offset, count: 10)
                switch try reader.uint16(at: offset) {
                case 1: return [.pair(try parseGlyphPairs(at: offset, table: table, reader: reader))]
                case 2: return [.pair(try parseClassPairs(at: offset, table: table, reader: reader))]
                default: throw SFNT.RegistrationError.malformedRequiredTable
                }
            case 3:
                return [.cursive(try parseCursive(at: offset, table: table, reader: reader))]
            case 4:
                return [.markToBase(try parseMarkToBase(at: offset, table: table, reader: reader))]
            case 5:
                return [.markToLigature(try parseMarkToLigature(
                    at: offset,
                    table: table,
                    reader: reader
                ))]
            case 6:
                return [.markToMark(try parseMarkToBase(at: offset, table: table, reader: reader))]
            case 7:
                return try OpenTypeLayout.contextRules(
                    at: offset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                ).map(Subtable.context)
            case 8:
                return try OpenTypeLayout.chainedContextRules(
                    at: offset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                ).map(Subtable.context)
            default:
                return []
            }
        }

        private static func parseSingleAdjustments(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [SingleRule] {
            try require(table, at: offset, count: 6)
            let format = try reader.uint16(at: offset)
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let valueFormat = try reader.uint16(at: offset + 4)
            guard coverageOffset > 0, validValueFormat(valueFormat) else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let glyphs = try OpenTypeLayout.coverage(
                at: offset + coverageOffset,
                table: table,
                reader: reader
            ).glyphs
            switch format {
            case 1:
                try require(table, at: offset + 6, count: valueSize(valueFormat))
                var cursor = offset + 6
                let adjustment = try value(
                    at: &cursor,
                    format: valueFormat,
                    base: offset,
                    table: table,
                    reader: reader
                )
                return glyphs.map { .init(glyph: $0, adjustment: adjustment) }
            case 2:
                try require(table, at: offset, count: 8)
                let count = Int(try reader.uint16(at: offset + 6))
                guard count == glyphs.count else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                let recordSize = valueSize(valueFormat)
                let (byteCount, overflow) = count.multipliedReportingOverflow(by: recordSize)
                guard !overflow else { throw SFNT.RegistrationError.malformedRequiredTable }
                try require(table, at: offset + 8, count: byteCount)
                var cursor = offset + 8
                return try glyphs.map {
                    .init(
                        glyph: $0,
                        adjustment: try value(
                            at: &cursor,
                            format: valueFormat,
                            base: offset,
                            table: table,
                            reader: reader
                        )
                    )
                }
            default:
                throw SFNT.RegistrationError.malformedRequiredTable
            }
        }

        private static func parseCursive(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [CursiveRecord] {
            try require(table, at: offset, count: 6)
            guard try reader.uint16(at: offset) == 1 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let count = Int(try reader.uint16(at: offset + 4))
            guard coverageOffset > 0 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let glyphs = try OpenTypeLayout.coverage(
                at: offset + coverageOffset,
                table: table,
                reader: reader
            ).glyphs
            guard glyphs.count == count else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let (byteCount, overflow) = count.multipliedReportingOverflow(by: 4)
            guard !overflow else { throw SFNT.RegistrationError.malformedRequiredTable }
            try require(table, at: offset + 6, count: byteCount)
            return try (0..<count).map { index in
                let record = offset + 6 + index * 4
                return .init(
                    glyph: glyphs[index],
                    entry: try optionalAnchor(
                        relativeOffset: Int(try reader.uint16(at: record)),
                        base: offset,
                        table: table,
                        reader: reader
                    ),
                    exit: try optionalAnchor(
                        relativeOffset: Int(try reader.uint16(at: record + 2)),
                        base: offset,
                        table: table,
                        reader: reader
                    )
                )
            }
        }

        private static func parseMarkToBase(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> MarkToBaseTable {
            try require(table, at: offset, count: 12)
            guard try reader.uint16(at: offset) == 1 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let markCoverageOffset = Int(try reader.uint16(at: offset + 2))
            let baseCoverageOffset = Int(try reader.uint16(at: offset + 4))
            let classCount = Int(try reader.uint16(at: offset + 6))
            let markArrayOffset = Int(try reader.uint16(at: offset + 8))
            let baseArrayOffset = Int(try reader.uint16(at: offset + 10))
            guard markCoverageOffset > 0,
                  baseCoverageOffset > 0,
                  classCount > 0,
                  markArrayOffset > 0,
                  baseArrayOffset > 0
            else { throw SFNT.RegistrationError.malformedRequiredTable }
            let markGlyphs = try OpenTypeLayout.coverage(
                at: offset + markCoverageOffset,
                table: table,
                reader: reader
            ).glyphs
            let baseGlyphs = try OpenTypeLayout.coverage(
                at: offset + baseCoverageOffset,
                table: table,
                reader: reader
            ).glyphs
            return .init(
                marks: try parseMarks(
                    at: offset + markArrayOffset,
                    glyphs: markGlyphs,
                    classCount: classCount,
                    table: table,
                    reader: reader
                ),
                bases: try parseBases(
                    at: offset + baseArrayOffset,
                    glyphs: baseGlyphs,
                    classCount: classCount,
                    table: table,
                    reader: reader
                ),
                classCount: classCount
            )
        }

        private static func parseMarkToLigature(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> MarkToLigatureTable {
            try require(table, at: offset, count: 12)
            guard try reader.uint16(at: offset) == 1 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let markCoverageOffset = Int(try reader.uint16(at: offset + 2))
            let ligatureCoverageOffset = Int(try reader.uint16(at: offset + 4))
            let classCount = Int(try reader.uint16(at: offset + 6))
            let markArrayOffset = Int(try reader.uint16(at: offset + 8))
            let ligatureArrayOffset = Int(try reader.uint16(at: offset + 10))
            guard markCoverageOffset > 0,
                  ligatureCoverageOffset > 0,
                  classCount > 0,
                  markArrayOffset > 0,
                  ligatureArrayOffset > 0
            else { throw SFNT.RegistrationError.malformedRequiredTable }
            let markGlyphs = try OpenTypeLayout.coverage(
                at: offset + markCoverageOffset,
                table: table,
                reader: reader
            ).glyphs
            let ligatureGlyphs = try OpenTypeLayout.coverage(
                at: offset + ligatureCoverageOffset,
                table: table,
                reader: reader
            ).glyphs
            return .init(
                marks: try parseMarks(
                    at: offset + markArrayOffset,
                    glyphs: markGlyphs,
                    classCount: classCount,
                    table: table,
                    reader: reader
                ),
                ligatures: try parseLigatures(
                    at: offset + ligatureArrayOffset,
                    glyphs: ligatureGlyphs,
                    classCount: classCount,
                    table: table,
                    reader: reader
                ),
                classCount: classCount
            )
        }

        private static func parseMarks(
            at offset: Int,
            glyphs: [UInt16],
            classCount: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [MarkRecord] {
            try require(table, at: offset, count: 2)
            let count = Int(try reader.uint16(at: offset))
            guard count == glyphs.count else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let (byteCount, overflow) = count.multipliedReportingOverflow(by: 4)
            guard !overflow else { throw SFNT.RegistrationError.malformedRequiredTable }
            try require(table, at: offset + 2, count: byteCount)
            return try (0..<count).map { index in
                let record = offset + 2 + index * 4
                let markClass = try reader.uint16(at: record)
                let anchorOffset = Int(try reader.uint16(at: record + 2))
                guard Int(markClass) < classCount, anchorOffset > 0 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                return .init(
                    glyph: glyphs[index],
                    markClass: markClass,
                    anchor: try OpenTypeLayout.anchor(
                        at: offset + anchorOffset,
                        table: table,
                        reader: reader
                    )
                )
            }
        }

        private static func parseBases(
            at offset: Int,
            glyphs: [UInt16],
            classCount: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [BaseRecord] {
            try require(table, at: offset, count: 2)
            let count = Int(try reader.uint16(at: offset))
            guard count == glyphs.count else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            let (recordCount, countOverflow) = count.multipliedReportingOverflow(by: classCount)
            let (byteCount, byteOverflow) = recordCount.multipliedReportingOverflow(by: 2)
            guard !countOverflow, !byteOverflow else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            try require(table, at: offset + 2, count: byteCount)
            return try (0..<count).map { glyphIndex in
                let record = offset + 2 + glyphIndex * classCount * 2
                return .init(
                    glyph: glyphs[glyphIndex],
                    anchors: try (0..<classCount).map { classIndex in
                        try optionalAnchor(
                            relativeOffset: Int(try reader.uint16(at: record + classIndex * 2)),
                            base: offset,
                            table: table,
                            reader: reader
                        )
                    }
                )
            }
        }

        private static func parseLigatures(
            at offset: Int,
            glyphs: [UInt16],
            classCount: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [LigatureRecord] {
            try require(table, at: offset, count: 2)
            let count = Int(try reader.uint16(at: offset))
            guard count == glyphs.count else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            try require(table, at: offset + 2, count: count * 2)
            return try (0..<count).map { glyphIndex in
                let attachOffset = Int(try reader.uint16(at: offset + 2 + glyphIndex * 2))
                guard attachOffset > 0 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                let attach = offset + attachOffset
                try require(table, at: attach, count: 2)
                let componentCount = Int(try reader.uint16(at: attach))
                guard componentCount > 0 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                let (recordCount, countOverflow) = componentCount.multipliedReportingOverflow(
                    by: classCount
                )
                let (byteCount, byteOverflow) = recordCount.multipliedReportingOverflow(by: 2)
                guard !countOverflow, !byteOverflow else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                try require(table, at: attach + 2, count: byteCount)
                return .init(
                    glyph: glyphs[glyphIndex],
                    components: try (0..<componentCount).map { componentIndex in
                        let record = attach + 2 + componentIndex * classCount * 2
                        return try (0..<classCount).map { classIndex in
                            try optionalAnchor(
                                relativeOffset: Int(try reader.uint16(
                                    at: record + classIndex * 2
                                )),
                                base: attach,
                                table: table,
                                reader: reader
                            )
                        }
                    }
                )
            }
        }

        private static func optionalAnchor(
            relativeOffset: Int,
            base: Int,
            table: Table,
            reader: ByteReader
        ) throws -> OpenTypeLayout.Anchor? {
            guard relativeOffset != 0 else { return nil }
            return try OpenTypeLayout.anchor(
                at: base + relativeOffset,
                table: table,
                reader: reader
            )
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
                    let firstAdjustment = try value(
                        at: &cursor, format: firstFormat, base: offset, table: table, reader: reader
                    )
                    let secondAdjustment = try value(
                        at: &cursor, format: secondFormat, base: offset, table: table, reader: reader
                    )
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
                firstAdjustments.append(try value(
                    at: &cursor, format: firstFormat, base: offset, table: table, reader: reader
                ))
                secondAdjustments.append(try value(
                    at: &cursor, format: secondFormat, base: offset, table: table, reader: reader
                ))
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
            base: Int,
            table: Table,
            reader: ByteReader
        ) throws -> ValueAdjustment {
            var result = ValueAdjustment()
            if format & 0x0001 != 0 { result.xPlacement = Int32(try reader.int16(at: cursor)); cursor += 2 }
            if format & 0x0002 != 0 { result.yPlacement = Int32(try reader.int16(at: cursor)); cursor += 2 }
            if format & 0x0004 != 0 { result.xAdvance = Int32(try reader.int16(at: cursor)); cursor += 2 }
            if format & 0x0008 != 0 { result.yAdvance = Int32(try reader.int16(at: cursor)); cursor += 2 }
            for (bit, keyPath) in [
                (UInt16(0x0010), \ValueAdjustment.xPlacementVariation),
                (0x0020, \ValueAdjustment.yPlacementVariation),
                (0x0040, \ValueAdjustment.xAdvanceVariation),
                (0x0080, \ValueAdjustment.yAdvanceVariation)
            ] where format & bit != 0 {
                let relativeOffset = Int(try reader.uint16(at: cursor))
                cursor += 2
                if relativeOffset != 0 {
                    result[keyPath: keyPath] = try OpenTypeLayout.variationIndex(
                        at: base + relativeOffset,
                        table: table,
                        reader: reader
                    )
                }
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
            try OpenTypeLayout.classDefinition(
                at: offset,
                table: table,
                reader: reader
            ).ranges.map {
                .init(glyphs: $0.glyphs, value: $0.value)
            }
        }

        private static func coverageGlyphs(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [UInt16] {
            try OpenTypeLayout.coverage(
                at: offset,
                table: table,
                reader: reader
            ).glyphs
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
            switch feature {
            case 0x6B65_726E, // kern
                 0x6469_7374, // dist
                 0x6375_7273, // curs
                 0x6D61_726B, // mark
                 0x6D6B_6D6B, // mkmk
                 0x6162_766D, // abvm
                 0x626C_776D: // blwm
                true
            default:
                false
            }
        }

        private static func require(_ table: Table, at offset: Int, count: Int) throws {
            guard offset >= table.offset,
                  count >= 0,
                  offset <= table.offset + table.length - count
            else { throw SFNT.RegistrationError.malformedRequiredTable }
        }
    }
}
