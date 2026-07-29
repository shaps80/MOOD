extension SFNT {
    enum OpenTypeLayout {
        struct Coverage: Hashable {
            let glyphs: [UInt16]
        }

        struct ClassRange: Hashable {
            let glyphs: ClosedRange<UInt16>
            let value: UInt16
        }

        struct ClassDefinition: Hashable {
            let ranges: [ClassRange]
        }

        struct LookupFlags {
            let rawValue: UInt16
            let markFilteringSet: UInt16?

            var isRightToLeft: Bool { rawValue & 0x0001 != 0 }
            var ignoresBaseGlyphs: Bool { rawValue & 0x0002 != 0 }
            var ignoresLigatures: Bool { rawValue & 0x0004 != 0 }
            var ignoresMarks: Bool { rawValue & 0x0008 != 0 }
            var usesMarkFilteringSet: Bool { rawValue & 0x0010 != 0 }
            var markAttachmentType: UInt16 { rawValue >> 8 }
        }

        struct LookupRecord {
            let sequenceIndex: Int
            let lookupIndex: Int
        }

        enum Matcher {
            case glyph(UInt16)
            case coverage(Coverage)
            case glyphClass(ClassDefinition, UInt16)
        }

        struct ContextRule {
            let firstCoverage: Coverage?
            let backtrack: [Matcher]
            let input: [Matcher]
            let lookahead: [Matcher]
            let actions: [LookupRecord]
        }

        struct Anchor: Equatable {
            let x: Int16
            let y: Int16
        }

        static func coverage(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> Coverage {
            try require(table, at: offset, count: 4)
            switch try reader.uint16(at: offset) {
            case 1:
                let count = Int(try reader.uint16(at: offset + 2))
                try require(table, at: offset + 4, count: try byteCount(count, 2))
                var glyphs: [UInt16] = []
                glyphs.reserveCapacity(count)
                var previous: UInt16?
                for index in 0..<count {
                    let glyph = try reader.uint16(at: offset + 4 + index * 2)
                    guard previous.map({ $0 <= glyph }) ?? true else {
                        throw RegistrationError.malformedRequiredTable
                    }
                    glyphs.append(glyph)
                    previous = glyph
                }
                return .init(glyphs: glyphs)

            case 2:
                let count = Int(try reader.uint16(at: offset + 2))
                try require(table, at: offset + 4, count: try byteCount(count, 6))
                var glyphs: [UInt16] = []
                var previousEnd: UInt16?
                for index in 0..<count {
                    let record = offset + 4 + index * 6
                    let start = try reader.uint16(at: record)
                    let end = try reader.uint16(at: record + 2)
                    let coverageIndex = Int(try reader.uint16(at: record + 4))
                    guard start <= end,
                          previousEnd.map({ $0 < start }) ?? true,
                          coverageIndex == glyphs.count
                    else {
                        throw RegistrationError.malformedRequiredTable
                    }
                    let rangeCount = Int(end) - Int(start) + 1
                    guard glyphs.count <= Int(UInt16.max) + 1 - rangeCount else {
                        throw RegistrationError.malformedRequiredTable
                    }
                    glyphs.append(contentsOf: start...end)
                    previousEnd = end
                }
                return .init(glyphs: glyphs)

            default:
                throw RegistrationError.malformedRequiredTable
            }
        }

        static func classDefinition(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> ClassDefinition {
            try require(table, at: offset, count: 4)
            switch try reader.uint16(at: offset) {
            case 1:
                try require(table, at: offset, count: 6)
                let start = try reader.uint16(at: offset + 2)
                let count = Int(try reader.uint16(at: offset + 4))
                try require(table, at: offset + 6, count: try byteCount(count, 2))
                guard Int(start) + count <= Int(UInt16.max) + 1 else {
                    throw RegistrationError.malformedRequiredTable
                }
                var ranges: [ClassRange] = []
                ranges.reserveCapacity(count)
                for index in 0..<count {
                    let glyph = UInt16(Int(start) + index)
                    ranges.append(.init(
                        glyphs: glyph...glyph,
                        value: try reader.uint16(at: offset + 6 + index * 2)
                    ))
                }
                return .init(ranges: ranges)

            case 2:
                let count = Int(try reader.uint16(at: offset + 2))
                try require(table, at: offset + 4, count: try byteCount(count, 6))
                var ranges: [ClassRange] = []
                ranges.reserveCapacity(count)
                var previousEnd: UInt16?
                for index in 0..<count {
                    let record = offset + 4 + index * 6
                    let start = try reader.uint16(at: record)
                    let end = try reader.uint16(at: record + 2)
                    guard start <= end, previousEnd.map({ $0 < start }) ?? true else {
                        throw RegistrationError.malformedRequiredTable
                    }
                    ranges.append(.init(
                        glyphs: start...end,
                        value: try reader.uint16(at: record + 4)
                    ))
                    previousEnd = end
                }
                return .init(ranges: ranges)

            default:
                throw RegistrationError.malformedRequiredTable
            }
        }

        static func contextRules(
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [ContextRule] {
            try require(table, at: offset, count: 2)
            switch try reader.uint16(at: offset) {
            case 1:
                return try contextFormat1(
                    at: offset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                )
            case 2:
                return try contextFormat2(
                    at: offset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                )
            case 3:
                return try contextFormat3(
                    at: offset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                )
            default:
                throw RegistrationError.malformedRequiredTable
            }
        }

        static func chainedContextRules(
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [ContextRule] {
            try require(table, at: offset, count: 2)
            switch try reader.uint16(at: offset) {
            case 1:
                return try chainedFormat1(
                    at: offset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                )
            case 2:
                return try chainedFormat2(
                    at: offset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                )
            case 3:
                return try chainedFormat3(
                    at: offset,
                    table: table,
                    reader: reader,
                    lookupCount: lookupCount
                )
            default:
                throw RegistrationError.malformedRequiredTable
            }
        }

        static func anchor(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> Anchor {
            try require(table, at: offset, count: 6)
            switch try reader.uint16(at: offset) {
            case 1:
                break
            case 2:
                try require(table, at: offset, count: 8)
            case 3:
                try require(table, at: offset, count: 10)
            default:
                throw RegistrationError.malformedRequiredTable
            }
            return .init(
                x: try reader.int16(at: offset + 2),
                y: try reader.int16(at: offset + 4)
            )
        }

        static func validateReferences(
            scripts: [GlyphSubstitution.Script],
            features: [GlyphSubstitution.Feature],
            lookupCount: Int
        ) throws {
            for script in scripts {
                if let language = script.defaultLanguage {
                    try validate(
                        language: language,
                        featureCount: features.count
                    )
                }
                for language in script.languages {
                    try validate(
                        language: language.system,
                        featureCount: features.count
                    )
                }
            }
            for feature in features {
                guard feature.lookupIndices.allSatisfy({
                    $0 >= 0 && $0 < lookupCount
                }) else {
                    throw RegistrationError.malformedRequiredTable
                }
            }
        }

        static func require(_ table: Table, at offset: Int, count: Int) throws {
            guard offset >= table.offset,
                  count >= 0,
                  offset <= table.offset + table.length - count
            else {
                throw RegistrationError.malformedRequiredTable
            }
        }

        private static func validate(
            language: GlyphSubstitution.LanguageSystem,
            featureCount: Int
        ) throws {
            if let required = language.requiredFeatureIndex {
                guard required >= 0, required < featureCount else {
                    throw RegistrationError.malformedRequiredTable
                }
            }
            guard language.featureIndices.allSatisfy({
                $0 >= 0 && $0 < featureCount
            }) else {
                throw RegistrationError.malformedRequiredTable
            }
        }

        private static func contextFormat1(
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [ContextRule] {
            try require(table, at: offset, count: 6)
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let setCount = Int(try reader.uint16(at: offset + 4))
            guard coverageOffset > 0 else { throw RegistrationError.malformedRequiredTable }
            let first = try coverage(at: offset + coverageOffset, table: table, reader: reader)
            guard first.glyphs.count == setCount else {
                throw RegistrationError.malformedRequiredTable
            }
            try require(table, at: offset + 6, count: try byteCount(setCount, 2))
            var result: [ContextRule] = []
            for setIndex in 0..<setCount {
                let setOffset = Int(try reader.uint16(at: offset + 6 + setIndex * 2))
                guard setOffset != 0 else { continue }
                let set = offset + setOffset
                try require(table, at: set, count: 2)
                let ruleCount = Int(try reader.uint16(at: set))
                try require(table, at: set + 2, count: try byteCount(ruleCount, 2))
                for ruleIndex in 0..<ruleCount {
                    let ruleOffset = Int(try reader.uint16(at: set + 2 + ruleIndex * 2))
                    guard ruleOffset > 0 else { throw RegistrationError.malformedRequiredTable }
                    var cursor = set + ruleOffset
                    try require(table, at: cursor, count: 4)
                    let glyphCount = Int(try reader.uint16(at: cursor))
                    let actionCount = Int(try reader.uint16(at: cursor + 2))
                    guard glyphCount > 0 else { throw RegistrationError.malformedRequiredTable }
                    cursor += 4
                    try require(table, at: cursor, count: try byteCount(glyphCount - 1, 2))
                    var input: [Matcher] = [.glyph(first.glyphs[setIndex])]
                    for _ in 1..<glyphCount {
                        input.append(.glyph(try reader.uint16(at: cursor)))
                        cursor += 2
                    }
                    result.append(.init(
                        firstCoverage: nil,
                        backtrack: [],
                        input: input,
                        lookahead: [],
                        actions: try lookupRecords(
                            at: &cursor,
                            count: actionCount,
                            inputCount: glyphCount,
                            lookupCount: lookupCount,
                            table: table,
                            reader: reader
                        )
                    ))
                }
            }
            return result
        }

        private static func contextFormat2(
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [ContextRule] {
            try require(table, at: offset, count: 8)
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let classOffset = Int(try reader.uint16(at: offset + 4))
            let setCount = Int(try reader.uint16(at: offset + 6))
            guard coverageOffset > 0, classOffset > 0 else {
                throw RegistrationError.malformedRequiredTable
            }
            let first = try coverage(at: offset + coverageOffset, table: table, reader: reader)
            let classes = try classDefinition(at: offset + classOffset, table: table, reader: reader)
            try require(table, at: offset + 8, count: try byteCount(setCount, 2))
            var result: [ContextRule] = []
            for setIndex in 0..<setCount {
                let setOffset = Int(try reader.uint16(at: offset + 8 + setIndex * 2))
                guard setOffset != 0 else { continue }
                let set = offset + setOffset
                try require(table, at: set, count: 2)
                let ruleCount = Int(try reader.uint16(at: set))
                try require(table, at: set + 2, count: try byteCount(ruleCount, 2))
                for ruleIndex in 0..<ruleCount {
                    let ruleOffset = Int(try reader.uint16(at: set + 2 + ruleIndex * 2))
                    guard ruleOffset > 0 else { throw RegistrationError.malformedRequiredTable }
                    var cursor = set + ruleOffset
                    try require(table, at: cursor, count: 4)
                    let glyphCount = Int(try reader.uint16(at: cursor))
                    let actionCount = Int(try reader.uint16(at: cursor + 2))
                    guard glyphCount > 0 else { throw RegistrationError.malformedRequiredTable }
                    cursor += 4
                    try require(table, at: cursor, count: try byteCount(glyphCount - 1, 2))
                    var input: [Matcher] = [.glyphClass(classes, UInt16(setIndex))]
                    for _ in 1..<glyphCount {
                        input.append(.glyphClass(classes, try reader.uint16(at: cursor)))
                        cursor += 2
                    }
                    result.append(.init(
                        firstCoverage: first,
                        backtrack: [],
                        input: input,
                        lookahead: [],
                        actions: try lookupRecords(
                            at: &cursor,
                            count: actionCount,
                            inputCount: glyphCount,
                            lookupCount: lookupCount,
                            table: table,
                            reader: reader
                        )
                    ))
                }
            }
            return result
        }

        private static func contextFormat3(
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [ContextRule] {
            try require(table, at: offset, count: 6)
            let glyphCount = Int(try reader.uint16(at: offset + 2))
            let actionCount = Int(try reader.uint16(at: offset + 4))
            guard glyphCount > 0 else { throw RegistrationError.malformedRequiredTable }
            var cursor = offset + 6
            try require(table, at: cursor, count: try byteCount(glyphCount, 2))
            var input: [Matcher] = []
            input.reserveCapacity(glyphCount)
            for _ in 0..<glyphCount {
                let coverageOffset = Int(try reader.uint16(at: cursor))
                guard coverageOffset > 0 else { throw RegistrationError.malformedRequiredTable }
                input.append(.coverage(try coverage(
                    at: offset + coverageOffset,
                    table: table,
                    reader: reader
                )))
                cursor += 2
            }
            return [.init(
                firstCoverage: nil,
                backtrack: [],
                input: input,
                lookahead: [],
                actions: try lookupRecords(
                    at: &cursor,
                    count: actionCount,
                    inputCount: glyphCount,
                    lookupCount: lookupCount,
                    table: table,
                    reader: reader
                )
            )]
        }

        private static func chainedFormat1(
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [ContextRule] {
            try require(table, at: offset, count: 6)
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let setCount = Int(try reader.uint16(at: offset + 4))
            guard coverageOffset > 0 else { throw RegistrationError.malformedRequiredTable }
            let first = try coverage(at: offset + coverageOffset, table: table, reader: reader)
            guard first.glyphs.count == setCount else {
                throw RegistrationError.malformedRequiredTable
            }
            try require(table, at: offset + 6, count: try byteCount(setCount, 2))
            var result: [ContextRule] = []
            for setIndex in 0..<setCount {
                let setOffset = Int(try reader.uint16(at: offset + 6 + setIndex * 2))
                guard setOffset != 0 else { continue }
                let set = offset + setOffset
                try require(table, at: set, count: 2)
                let ruleCount = Int(try reader.uint16(at: set))
                try require(table, at: set + 2, count: try byteCount(ruleCount, 2))
                for ruleIndex in 0..<ruleCount {
                    let ruleOffset = Int(try reader.uint16(at: set + 2 + ruleIndex * 2))
                    guard ruleOffset > 0 else { throw RegistrationError.malformedRequiredTable }
                    var cursor = set + ruleOffset
                    let backtrack = try glyphMatchers(at: &cursor, table: table, reader: reader)
                    let followingInput = try glyphMatchers(
                        at: &cursor,
                        omittingFirst: true,
                        table: table,
                        reader: reader
                    )
                    let lookahead = try glyphMatchers(at: &cursor, table: table, reader: reader)
                    try require(table, at: cursor, count: 2)
                    let actionCount = Int(try reader.uint16(at: cursor))
                    cursor += 2
                    let input = [.glyph(first.glyphs[setIndex])] + followingInput
                    result.append(.init(
                        firstCoverage: nil,
                        backtrack: backtrack,
                        input: input,
                        lookahead: lookahead,
                        actions: try lookupRecords(
                            at: &cursor,
                            count: actionCount,
                            inputCount: input.count,
                            lookupCount: lookupCount,
                            table: table,
                            reader: reader
                        )
                    ))
                }
            }
            return result
        }

        private static func chainedFormat2(
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [ContextRule] {
            try require(table, at: offset, count: 12)
            let coverageOffset = Int(try reader.uint16(at: offset + 2))
            let backtrackClassOffset = Int(try reader.uint16(at: offset + 4))
            let inputClassOffset = Int(try reader.uint16(at: offset + 6))
            let lookaheadClassOffset = Int(try reader.uint16(at: offset + 8))
            let setCount = Int(try reader.uint16(at: offset + 10))
            guard coverageOffset > 0, inputClassOffset > 0 else {
                throw RegistrationError.malformedRequiredTable
            }
            let first = try coverage(at: offset + coverageOffset, table: table, reader: reader)
            let backtrackClasses = try optionalClassDefinition(
                relativeOffset: backtrackClassOffset,
                base: offset,
                table: table,
                reader: reader
            )
            let inputClasses = try classDefinition(
                at: offset + inputClassOffset,
                table: table,
                reader: reader
            )
            let lookaheadClasses = try optionalClassDefinition(
                relativeOffset: lookaheadClassOffset,
                base: offset,
                table: table,
                reader: reader
            )
            try require(table, at: offset + 12, count: try byteCount(setCount, 2))
            var result: [ContextRule] = []
            for setIndex in 0..<setCount {
                let setOffset = Int(try reader.uint16(at: offset + 12 + setIndex * 2))
                guard setOffset != 0 else { continue }
                let set = offset + setOffset
                try require(table, at: set, count: 2)
                let ruleCount = Int(try reader.uint16(at: set))
                try require(table, at: set + 2, count: try byteCount(ruleCount, 2))
                for ruleIndex in 0..<ruleCount {
                    let ruleOffset = Int(try reader.uint16(at: set + 2 + ruleIndex * 2))
                    guard ruleOffset > 0 else { throw RegistrationError.malformedRequiredTable }
                    var cursor = set + ruleOffset
                    let backtrack = try classMatchers(
                        at: &cursor,
                        definition: backtrackClasses,
                        table: table,
                        reader: reader
                    )
                    let followingInput = try classMatchers(
                        at: &cursor,
                        definition: inputClasses,
                        omittingFirst: true,
                        table: table,
                        reader: reader
                    )
                    let lookahead = try classMatchers(
                        at: &cursor,
                        definition: lookaheadClasses,
                        table: table,
                        reader: reader
                    )
                    try require(table, at: cursor, count: 2)
                    let actionCount = Int(try reader.uint16(at: cursor))
                    cursor += 2
                    let input = [.glyphClass(inputClasses, UInt16(setIndex))] + followingInput
                    result.append(.init(
                        firstCoverage: first,
                        backtrack: backtrack,
                        input: input,
                        lookahead: lookahead,
                        actions: try lookupRecords(
                            at: &cursor,
                            count: actionCount,
                            inputCount: input.count,
                            lookupCount: lookupCount,
                            table: table,
                            reader: reader
                        )
                    ))
                }
            }
            return result
        }

        private static func chainedFormat3(
            at offset: Int,
            table: Table,
            reader: ByteReader,
            lookupCount: Int
        ) throws -> [ContextRule] {
            try require(table, at: offset, count: 4)
            var cursor = offset + 2
            let backtrack = try coverageMatchers(
                at: &cursor,
                relativeTo: offset,
                table: table,
                reader: reader
            )
            let input = try coverageMatchers(
                at: &cursor,
                relativeTo: offset,
                table: table,
                reader: reader
            )
            guard !input.isEmpty else { throw RegistrationError.malformedRequiredTable }
            let lookahead = try coverageMatchers(
                at: &cursor,
                relativeTo: offset,
                table: table,
                reader: reader
            )
            try require(table, at: cursor, count: 2)
            let actionCount = Int(try reader.uint16(at: cursor))
            cursor += 2
            return [.init(
                firstCoverage: nil,
                backtrack: backtrack,
                input: input,
                lookahead: lookahead,
                actions: try lookupRecords(
                    at: &cursor,
                    count: actionCount,
                    inputCount: input.count,
                    lookupCount: lookupCount,
                    table: table,
                    reader: reader
                )
            )]
        }

        private static func glyphMatchers(
            at cursor: inout Int,
            omittingFirst: Bool = false,
            table: Table,
            reader: ByteReader
        ) throws -> [Matcher] {
            try require(table, at: cursor, count: 2)
            let encodedCount = Int(try reader.uint16(at: cursor))
            guard !omittingFirst || encodedCount > 0 else {
                throw RegistrationError.malformedRequiredTable
            }
            let count = encodedCount - (omittingFirst ? 1 : 0)
            cursor += 2
            try require(table, at: cursor, count: try byteCount(count, 2))
            var result: [Matcher] = []
            result.reserveCapacity(count)
            for _ in 0..<count {
                result.append(.glyph(try reader.uint16(at: cursor)))
                cursor += 2
            }
            return result
        }

        private static func classMatchers(
            at cursor: inout Int,
            definition: ClassDefinition,
            omittingFirst: Bool = false,
            table: Table,
            reader: ByteReader
        ) throws -> [Matcher] {
            try require(table, at: cursor, count: 2)
            let encodedCount = Int(try reader.uint16(at: cursor))
            guard !omittingFirst || encodedCount > 0 else {
                throw RegistrationError.malformedRequiredTable
            }
            let count = encodedCount - (omittingFirst ? 1 : 0)
            cursor += 2
            try require(table, at: cursor, count: try byteCount(count, 2))
            var result: [Matcher] = []
            result.reserveCapacity(count)
            for _ in 0..<count {
                result.append(.glyphClass(definition, try reader.uint16(at: cursor)))
                cursor += 2
            }
            return result
        }

        private static func coverageMatchers(
            at cursor: inout Int,
            relativeTo base: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [Matcher] {
            try require(table, at: cursor, count: 2)
            let count = Int(try reader.uint16(at: cursor))
            cursor += 2
            try require(table, at: cursor, count: try byteCount(count, 2))
            var result: [Matcher] = []
            result.reserveCapacity(count)
            for _ in 0..<count {
                let relativeOffset = Int(try reader.uint16(at: cursor))
                guard relativeOffset > 0 else { throw RegistrationError.malformedRequiredTable }
                result.append(.coverage(try coverage(
                    at: base + relativeOffset,
                    table: table,
                    reader: reader
                )))
                cursor += 2
            }
            return result
        }

        private static func optionalClassDefinition(
            relativeOffset: Int,
            base: Int,
            table: Table,
            reader: ByteReader
        ) throws -> ClassDefinition {
            guard relativeOffset != 0 else { return .init(ranges: []) }
            return try classDefinition(
                at: base + relativeOffset,
                table: table,
                reader: reader
            )
        }

        private static func lookupRecords(
            at cursor: inout Int,
            count: Int,
            inputCount: Int,
            lookupCount: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [LookupRecord] {
            try require(table, at: cursor, count: try byteCount(count, 4))
            var result: [LookupRecord] = []
            result.reserveCapacity(count)
            for _ in 0..<count {
                let sequenceIndex = Int(try reader.uint16(at: cursor))
                let lookupIndex = Int(try reader.uint16(at: cursor + 2))
                guard sequenceIndex < inputCount, lookupIndex < lookupCount else {
                    throw RegistrationError.malformedRequiredTable
                }
                result.append(.init(sequenceIndex: sequenceIndex, lookupIndex: lookupIndex))
                cursor += 4
            }
            return result
        }

        private static func byteCount(_ count: Int, _ stride: Int) throws -> Int {
            let (result, overflow) = count.multipliedReportingOverflow(by: stride)
            guard !overflow else { throw RegistrationError.malformedRequiredTable }
            return result
        }
    }
}
