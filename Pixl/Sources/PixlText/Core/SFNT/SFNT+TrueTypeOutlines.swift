extension SFNT {
    struct TrueTypeOutlines {
        let locations: Table
        let glyphs: Table
        let locationFormat: Int16

        func bounds(for glyph: GlyphID, bytes: [UInt8]) -> GlyphBounds? {
            let index = Int(glyph.rawValue)
            let reader = ByteReader(bytes)

            guard
                let start = try? glyphOffset(at: index, reader: reader),
                let end = try? glyphOffset(at: index + 1, reader: reader),
                start < end,
                start >= 0,
                end <= glyphs.length,
                start <= glyphs.length - 10
            else {
                return nil
            }

            let offset = glyphs.offset + start
            guard
                let xMin = try? reader.int16(at: offset + 2),
                let yMin = try? reader.int16(at: offset + 4),
                let xMax = try? reader.int16(at: offset + 6),
                let yMax = try? reader.int16(at: offset + 8)
            else {
                return nil
            }

            return .init(xMin: xMin, yMin: yMin, xMax: xMax, yMax: yMax)
        }

        private func glyphOffset(at index: Int, reader: ByteReader) throws -> Int {
            switch locationFormat {
            case 0:
                return Int(try reader.uint16(at: locations.offset + index * 2)) * 2
            case 1:
                return Int(try reader.uint32(at: locations.offset + index * 4))
            default:
                throw RegistrationError.malformedRequiredTable
            }
        }
    }
}
