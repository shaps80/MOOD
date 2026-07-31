extension SFNT {
    struct GlyphDefinition {
        enum GlyphClass: UInt16 {
            case unclassified = 0
            case base = 1
            case ligature = 2
            case mark = 3
            case component = 4
        }

        let glyphClasses: OpenTypeLayout.ClassDefinition?
        let markAttachmentClasses: OpenTypeLayout.ClassDefinition?
        let markGlyphSets: [OpenTypeLayout.Coverage]
        let itemVariationStore: ItemVariationStore?

        static func validate(
            flags: OpenTypeLayout.LookupFlags,
            against definition: GlyphDefinition?
        ) throws {
            if flags.markAttachmentType != 0 {
                guard definition?.markAttachmentClasses != nil else {
                    throw RegistrationError.malformedRequiredTable
                }
            }
            if flags.usesMarkFilteringSet {
                guard let set = flags.markFilteringSet,
                      let definition,
                      definition.markGlyphSets.indices.contains(Int(set))
                else {
                    throw RegistrationError.malformedRequiredTable
                }
            }
        }

        func ignores(glyph: UInt16, flags: OpenTypeLayout.LookupFlags) -> Bool {
            let glyphClass = classValue(glyph, in: glyphClasses)
            if flags.ignoresBaseGlyphs, glyphClass == GlyphClass.base.rawValue { return true }
            if flags.ignoresLigatures, glyphClass == GlyphClass.ligature.rawValue { return true }
            guard glyphClass == GlyphClass.mark.rawValue else { return false }
            if flags.ignoresMarks { return true }
            if flags.usesMarkFilteringSet,
               let setIndex = flags.markFilteringSet,
               markGlyphSets.indices.contains(Int(setIndex)) {
                return !contains(glyph, in: markGlyphSets[Int(setIndex)].glyphs)
            }
            let attachmentType = flags.markAttachmentType
            return attachmentType != 0
                && classValue(glyph, in: markAttachmentClasses) != attachmentType
        }

        static func parse(table: Table, bytes: [UInt8]) throws -> Self {
            let reader = ByteReader(bytes)
            try OpenTypeLayout.require(table, at: table.offset, count: 12)
            let major = try reader.uint16(at: table.offset)
            let minor = try reader.uint16(at: table.offset + 2)
            guard major == 1, minor == 0 || minor == 2 || minor == 3 else {
                throw RegistrationError.malformedRequiredTable
            }
            let glyphClassOffset = Int(try reader.uint16(at: table.offset + 4))
            let markAttachmentOffset = Int(try reader.uint16(at: table.offset + 10))

            let glyphClasses = try glyphClassOffset == 0 ? nil : OpenTypeLayout.classDefinition(
                at: table.offset + glyphClassOffset,
                table: table,
                reader: reader
            )
            let markAttachmentClasses = try markAttachmentOffset == 0
                ? nil
                : OpenTypeLayout.classDefinition(
                    at: table.offset + markAttachmentOffset,
                    table: table,
                    reader: reader
                )

            let markGlyphSets: [OpenTypeLayout.Coverage]
            if minor >= 2 {
                try OpenTypeLayout.require(table, at: table.offset, count: minor >= 3 ? 18 : 14)
                let setsOffset = Int(try reader.uint16(at: table.offset + 12))
                markGlyphSets = try setsOffset == 0
                    ? []
                    : parseMarkGlyphSets(
                        at: table.offset + setsOffset,
                        table: table,
                        reader: reader
                    )
            } else {
                markGlyphSets = []
            }

            let itemVariationStore: ItemVariationStore?
            if minor >= 3 {
                let storeOffset = Int(try reader.uint32(at: table.offset + 14))
                itemVariationStore = storeOffset == 0 ? nil : try ItemVariationStore.parse(
                    at: table.offset + storeOffset,
                    table: table,
                    reader: reader
                )
            } else {
                itemVariationStore = nil
            }

            return .init(
                glyphClasses: glyphClasses,
                markAttachmentClasses: markAttachmentClasses,
                markGlyphSets: markGlyphSets,
                itemVariationStore: itemVariationStore
            )
        }

        private static func parseMarkGlyphSets(
            at offset: Int,
            table: Table,
            reader: ByteReader
        ) throws -> [OpenTypeLayout.Coverage] {
            try OpenTypeLayout.require(table, at: offset, count: 4)
            guard try reader.uint16(at: offset) == 1 else {
                throw RegistrationError.malformedRequiredTable
            }
            let count = Int(try reader.uint16(at: offset + 2))
            let (byteCount, overflow) = count.multipliedReportingOverflow(by: 4)
            guard !overflow else { throw RegistrationError.malformedRequiredTable }
            try OpenTypeLayout.require(table, at: offset + 4, count: byteCount)
            return try (0..<count).map { index in
                let relativeOffset = Int(try reader.uint32(at: offset + 4 + index * 4))
                guard relativeOffset > 0 else {
                    throw RegistrationError.malformedRequiredTable
                }
                return try OpenTypeLayout.coverage(
                    at: offset + relativeOffset,
                    table: table,
                    reader: reader
                )
            }
        }

        private func classValue(
            _ glyph: UInt16,
            in definition: OpenTypeLayout.ClassDefinition?
        ) -> UInt16 {
            guard let ranges = definition?.ranges else { return 0 }
            var lower = 0
            var upper = ranges.count
            while lower < upper {
                let middle = lower + (upper - lower) / 2
                if ranges[middle].glyphs.upperBound < glyph {
                    lower = middle + 1
                } else {
                    upper = middle
                }
            }
            guard lower < ranges.count, ranges[lower].glyphs.contains(glyph) else { return 0 }
            return ranges[lower].value
        }

        private func contains(_ glyph: UInt16, in sorted: [UInt16]) -> Bool {
            var lower = 0
            var upper = sorted.count
            while lower < upper {
                let middle = lower + (upper - lower) / 2
                if sorted[middle] < glyph {
                    lower = middle + 1
                } else {
                    upper = middle
                }
            }
            return lower < sorted.count && sorted[lower] == glyph
        }
    }
}
