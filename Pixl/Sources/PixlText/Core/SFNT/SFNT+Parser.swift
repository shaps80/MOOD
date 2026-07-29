extension SFNT {
    enum Parser {
        private static let trueType: UInt32 = 0x0001_0000
        private static let openType: UInt32 = 0x4F54_544F
        private static let head: UInt32 = 0x6865_6164
        private static let hhea: UInt32 = 0x6868_6561
        private static let hmtx: UInt32 = 0x686D_7478
        private static let maxp: UInt32 = 0x6D61_7870
        private static let cmap: UInt32 = 0x636D_6170
        private static let loca: UInt32 = 0x6C6F_6361
        private static let glyf: UInt32 = 0x676C_7966
        private static let gsub: UInt32 = 0x4753_5542
        
        struct ParsedFace {
            let metrics: SFNT.FaceMetrics
            let glyphCount: UInt16
            let tableCount: UInt16
            let horizontalMetricsCount: UInt16
            let horizontalMetricsTable: Table
            let characterMap: CharacterMap
            let trueTypeOutlines: TrueTypeOutlines?
            let glyphSubstitution: GlyphSubstitution?
        }
        
        static func parse(bytes: [UInt8]) throws -> ParsedFace {
            let reader = ByteReader(bytes)
            guard bytes.count >= 12 else { throw SFNT.RegistrationError.invalid }
            let scalerType = try reader.uint32(at: 0)
            guard scalerType == trueType || scalerType == openType else {
                throw SFNT.RegistrationError.invalid
            }
            
            let tableCount = try reader.uint16(at: 4)
            let directoryLength = 12 + Int(tableCount) * 16
            guard directoryLength <= bytes.count else {
                throw SFNT.RegistrationError.malformedTableDirectory
            }
            
            var headTable: Table?
            var hheaTable: Table?
            var hmtxTable: Table?
            var maxpTable: Table?
            var cmapTable: Table?
            var locaTable: Table?
            var glyfTable: Table?
            var gsubTable: Table?
            
            for index in 0..<Int(tableCount) {
                let record = 12 + index * 16
                let tag = try reader.uint32(at: record)
                let offset = Int(try reader.uint32(at: record + 8))
                let length = Int(try reader.uint32(at: record + 12))
                guard offset >= 0, length >= 0, offset <= bytes.count - length else {
                    throw SFNT.RegistrationError.malformedTableDirectory
                }
                let table = Table(offset: offset, length: length)
                
                switch tag {
                case head: headTable = table
                case hhea: hheaTable = table
                case hmtx: hmtxTable = table
                case maxp: maxpTable = table
                case cmap: cmapTable = table
                case loca: locaTable = table
                case glyf: glyfTable = table
                case gsub: gsubTable = table
                default: break
                }
            }
            
            guard
                let headTable,
                let hheaTable,
                let hmtxTable,
                let maxpTable,
                let cmapTable
                    else {
                throw SFNT.RegistrationError.missingRequiredTable
            }
            
            guard
                headTable.length >= 20,
                hheaTable.length >= 36,
                maxpTable.length >= 6
                    else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            
            let unitsPerEm = try reader.uint16(at: headTable.offset + 18)
            guard unitsPerEm > 0 else { throw SFNT.RegistrationError.malformedRequiredTable }
            let ascender = try reader.int16(at: hheaTable.offset + 4)
            let descender = try reader.int16(at: hheaTable.offset + 6)
            let lineGap = try reader.int16(at: hheaTable.offset + 8)
            let horizontalMetricsCount = try reader.uint16(at: hheaTable.offset + 34)
            let glyphCount = try reader.uint16(at: maxpTable.offset + 4)
            guard horizontalMetricsCount > 0, horizontalMetricsCount <= glyphCount else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            guard hmtxTable.length >= Int(horizontalMetricsCount) * 4 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }

            let trueTypeOutlines: TrueTypeOutlines?
            if scalerType == trueType {
                guard
                    headTable.length >= 54,
                    let locaTable,
                    let glyfTable
                else {
                    throw SFNT.RegistrationError.missingRequiredTable
                }

                let locationFormat = try reader.int16(at: headTable.offset + 50)
                guard locationFormat == 0 || locationFormat == 1 else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                let entrySize = locationFormat == 0 ? 2 : 4
                guard locaTable.length >= (Int(glyphCount) + 1) * entrySize else {
                    throw SFNT.RegistrationError.malformedRequiredTable
                }
                trueTypeOutlines = .init(
                    locations: locaTable,
                    glyphs: glyfTable,
                    locationFormat: locationFormat
                )
            } else {
                trueTypeOutlines = nil
            }

            let glyphSubstitution = try gsubTable.map {
                try GlyphSubstitution.parse(table: $0, bytes: bytes)
            }
            
            return .init(
                metrics: .init(
                    unitsPerEm: unitsPerEm,
                    ascender: ascender,
                    descender: descender,
                    lineGap: lineGap
                ),
                glyphCount: glyphCount,
                tableCount: tableCount,
                horizontalMetricsCount: horizontalMetricsCount,
                horizontalMetricsTable: hmtxTable,
                characterMap: try characterMap(in: cmapTable, reader: reader),
                trueTypeOutlines: trueTypeOutlines,
                glyphSubstitution: glyphSubstitution
            )
        }
        
        private static func characterMap(
            in table: Table,
            reader: ByteReader
        ) throws -> CharacterMap {
            guard table.length >= 4 else { throw SFNT.RegistrationError.malformedRequiredTable }
            let subtableCount = Int(try reader.uint16(at: table.offset + 2))
            guard table.length >= 4 + subtableCount * 8 else {
                throw SFNT.RegistrationError.malformedRequiredTable
            }
            
            var preferred: (rank: Int, map: CharacterMap)?
            
            for index in 0..<subtableCount {
                let record = table.offset + 4 + index * 8
                let platform = try reader.uint16(at: record)
                let encoding = try reader.uint16(at: record + 2)
                let relativeOffset = Int(try reader.uint32(at: record + 4))
                guard relativeOffset >= 0, relativeOffset < table.length else { continue }
                let offset = table.offset + relativeOffset
                let format = try reader.uint16(at: offset)
                
                let candidate: (rank: Int, map: CharacterMap)?
                switch format {
                case 12:
                    guard offset + 16 <= table.offset + table.length else { continue }
                    let length = Int(try reader.uint32(at: offset + 4))
                    let groups = Int(try reader.uint32(at: offset + 12))
                    guard length >= 16, length <= table.offset + table.length - offset,
                          groups <= (length - 16) / 12
                            else { continue }
                    candidate = (rank: cmapRank(platform: platform, encoding: encoding, format: format), map: .format12(.init(offset: offset, groupCount: groups)))
                case 4:
                    guard offset + 8 <= table.offset + table.length else { continue }
                    let length = Int(try reader.uint16(at: offset + 2))
                    let segments = Int(try reader.uint16(at: offset + 6)) / 2
                    guard length >= 16, length <= table.offset + table.length - offset,
                          segments > 0, 16 + segments * 8 <= length
                            else { continue }
                    candidate = (rank: cmapRank(platform: platform, encoding: encoding, format: format), map: .format4(.init(offset: offset, segmentCount: segments)))
                default:
                    candidate = nil
                }
                
                guard let candidate, candidate.rank > 0 else { continue }
                if preferred == nil || candidate.rank > preferred!.rank {
                    preferred = candidate
                }
            }
            
            guard let preferred else { throw SFNT.RegistrationError.unsupportedCharacterMap }
            return preferred.map
        }
        
        private static func cmapRank(platform: UInt16, encoding: UInt16, format: UInt16) -> Int {
            switch (platform, encoding, format) {
            case (3, 10, 12): 4
            case (0, _, 12): 3
            case (3, 1, 4): 2
            case (0, _, 4): 1
            default: 0
            }
        }
    }
}
