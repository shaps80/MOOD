extension SFNT {
    final class FaceStorage {
        let bytes: [UInt8]
        let metrics: SFNT.FaceMetrics
        let glyphCount: UInt16
        let tableCount: UInt16
        
        private let horizontalMetricsCount: UInt16
        private let horizontalMetricsTable: Table
        private let characterMap: CharacterMap
        private let trueTypeOutlines: TrueTypeOutlines?
        let glyphSubstitution: GlyphSubstitution?
        let glyphPositioning: GlyphPositioning?
        let glyphDefinition: GlyphDefinition?
        
        init(bytes: [UInt8]) throws {
            self.bytes = bytes
            let parsed = try Parser.parse(bytes: bytes)
            metrics = parsed.metrics
            glyphCount = parsed.glyphCount
            tableCount = parsed.tableCount
            horizontalMetricsCount = parsed.horizontalMetricsCount
            horizontalMetricsTable = parsed.horizontalMetricsTable
            characterMap = parsed.characterMap
            trueTypeOutlines = parsed.trueTypeOutlines
            glyphSubstitution = parsed.glyphSubstitution
            glyphPositioning = parsed.glyphPositioning
            glyphDefinition = parsed.glyphDefinition
        }
        
        func glyphID(for scalar: Unicode.Scalar) -> GlyphID? {
            characterMap.glyphID(for: scalar.value, bytes: bytes).map(GlyphID.init(rawValue:))
        }
        
        func advance(for glyph: GlyphID) -> UInt16 {
            let glyphIndex = Int(glyph.rawValue)
            let metricCount = Int(horizontalMetricsCount)
            guard metricCount > 0, glyphIndex < Int(glyphCount) else { return 0 }
            
            let metricIndex = min(glyphIndex, metricCount - 1)
            let offset = horizontalMetricsTable.offset + metricIndex * 4
            return (try? ByteReader(bytes).uint16(at: offset)) ?? 0
        }

        func renderBounds(for glyph: GlyphID) -> GlyphBounds? {
            guard Int(glyph.rawValue) < Int(glyphCount) else { return nil }
            return trueTypeOutlines?.bounds(for: glyph, bytes: bytes)
        }
    }
}
