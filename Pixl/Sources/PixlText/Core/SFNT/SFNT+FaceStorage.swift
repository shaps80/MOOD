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
        let variations: Variations?
        let metricsVariations: MetricsVariations?
        let glyphVariations: GlyphVariations?
        
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
            variations = parsed.variations
            metricsVariations = parsed.metricsVariations
            glyphVariations = parsed.glyphVariations
        }
        
        func glyphID(for scalar: Unicode.Scalar) -> GlyphID? {
            characterMap.glyphID(for: scalar.value, bytes: bytes).map(GlyphID.init(rawValue:))
        }
        
        func advance(for glyph: GlyphID, coordinates: [Float]) -> Int32 {
            let glyphIndex = Int(glyph.rawValue)
            let metricCount = Int(horizontalMetricsCount)
            guard metricCount > 0, glyphIndex < Int(glyphCount) else { return 0 }
            
            let metricIndex = min(glyphIndex, metricCount - 1)
            let offset = horizontalMetricsTable.offset + metricIndex * 4
            let base = Int32((try? ByteReader(bytes).uint16(at: offset)) ?? 0)
            guard coordinates.contains(where: { $0 != 0 }) else { return base }
            let delta = metricsVariations?.horizontalAdvanceDelta(
                glyph: glyphIndex,
                coordinates: coordinates
            ) ?? 0
            return base + Int32(delta.rounded())
        }

        func renderBounds(for glyph: GlyphID, coordinates: [Float]) -> GlyphBounds? {
            guard Int(glyph.rawValue) < Int(glyphCount) else { return nil }
            if coordinates.contains(where: { $0 != 0 }),
               let outlines = trueTypeOutlines,
               let outline = outlines.variedOutline(
                    for: glyph,
                    variations: glyphVariations,
                    coordinates: coordinates,
                    bytes: bytes
               ) {
                return outlines.bounds(of: outline)
            }
            return trueTypeOutlines?.bounds(for: glyph, bytes: bytes)
        }

        func face(id: FaceID, settings: [(UInt32, Float)]) -> Face {
            let coordinates = variations?.normalizedCoordinates(settings: settings) ?? []
            let ascenderDelta = metricsVariations?.globalDelta(
                tag: 0x6861_7363,
                coordinates: coordinates
            ) ?? 0
            let descenderDelta = metricsVariations?.globalDelta(
                tag: 0x6864_7363,
                coordinates: coordinates
            ) ?? 0
            let lineGapDelta = metricsVariations?.globalDelta(
                tag: 0x686C_6770,
                coordinates: coordinates
            ) ?? 0
            return .init(
                id: id,
                metrics: .init(
                    unitsPerEm: metrics.unitsPerEm,
                    ascender: clampedInt16(Float(metrics.ascender) + ascenderDelta),
                    descender: clampedInt16(Float(metrics.descender) + descenderDelta),
                    lineGap: clampedInt16(Float(metrics.lineGap) + lineGapDelta)
                ),
                glyphCount: glyphCount,
                tableCount: tableCount,
                normalizedCoordinates: coordinates
            )
        }

        private func clampedInt16(_ value: Float) -> Int16 {
            Int16(min(Float(Int16.max), max(Float(Int16.min), value.rounded())))
        }
    }
}
