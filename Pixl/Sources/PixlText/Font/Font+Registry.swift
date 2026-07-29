import PixlSynchronization

extension Font {
    final class Registry: @unchecked Sendable {
        private struct State {
            var systemFace: SFNT.Face?
            var debugFaces: [String: SFNT.Face] = [:]
        }

        enum Error: Swift.Error {
            case systemFontNotRegistered
        }

        static let shared = Registry()

        private let state = CriticalState(State())
        private let sfnt = SFNT.Registry()

        private init() {}

        func face(for descriptor: Descriptor) throws -> SFNT.Face {
            switch descriptor.source {
            case .system:
                return try state.withLock { state in
                    guard let systemFace = state.systemFace else {
                        throw Error.systemFontNotRegistered
                    }
                    return systemFace
                }
            }
        }

        func registerSystemFont(bytes: [UInt8]) throws {
            try state.withLock { state in
                guard state.systemFace == nil else { return }
                state.systemFace = try sfnt.register(bytes: bytes)
            }
        }

        func forEachGlyph(
            in text: String,
            descriptor: Descriptor,
            fontBytes: [UInt8]?,
            fontID: String?,
            _ body: (GlyphDebugInfo) -> Void
        ) throws {
            let face: SFNT.Face
            if let fontBytes, let fontID {
                face = try loadDebugFace(bytes: fontBytes, id: fontID)
            } else {
                face = try self.face(for: descriptor)
            }
            let metrics = face.metrics.scaled(to: descriptor.size)
            var x: Float = 0
            var sourceOffset = 0
            var glyphIndex = 0
            var normalizationBuffer = UnicodeNormalizationBuffer()

            var characterIndex = text.startIndex
            while characterIndex < text.endIndex {
                let nextCharacterIndex = text.index(after: characterIndex)
                let character = text[characterIndex..<nextCharacterIndex]
                let sourceRange = sourceOffset..<(sourceOffset + character.utf8.count)
                UnicodeNormalization.normalizeNFC(
                    character.unicodeScalars,
                    using: &normalizationBuffer
                )
                let glyphRange = glyphIndex..<(glyphIndex + normalizationBuffer.normalized.count)

                for scalar in normalizationBuffer.normalized {
                    let glyph = sfnt.glyphID(for: scalar, in: face) ?? .init(rawValue: 0)
                    let advance = sfnt.advance(
                        for: glyph,
                        in: face,
                        size: descriptor.size
                    ) ?? 0
                    let scale = descriptor.size / Float(face.metrics.unitsPerEm)
                    let rawRenderBounds = sfnt.renderBounds(for: glyph, in: face)

                    body(
                        .init(
                            scalar: scalar,
                            glyphID: glyph.rawValue,
                            cluster: .init(
                                sourceRange: sourceRange,
                                glyphRange: glyphRange
                            ),
                            advance: advance,
                            typographicBounds: .init(
                                x: x,
                                y: -metrics.ascent,
                                width: advance,
                                height: metrics.ascent + metrics.descent
                            ),
                            renderBounds: rawRenderBounds.map {
                                .init(
                                    x: x + Float($0.xMin) * scale,
                                    y: -Float($0.yMax) * scale,
                                    width: Float($0.xMax - $0.xMin) * scale,
                                    height: Float($0.yMax - $0.yMin) * scale
                                )
                            }
                        )
                    )
                    x += advance
                    glyphIndex += 1
                }

                sourceOffset = sourceRange.upperBound
                characterIndex = nextCharacterIndex
            }
        }

        func shapingDebugInfo(
            in text: String,
            fontBytes: [UInt8],
            fontID: String
        ) throws -> [ShapingDebugInfo] {
            let face = try loadDebugFace(bytes: fontBytes, id: fontID)
            var normalizationBuffer = UnicodeNormalizationBuffer()
            var nominalClusters: [(
                sourceRange: Range<Int>,
                scalars: [Unicode.Scalar],
                glyphs: [UInt16]
            )] = []
            var workspace = ShapingWorkspace(minimumGlyphCapacity: text.utf8.count)
            var runScript: UnicodeScript?
            var sourceOffset = 0
            var characterIndex = text.startIndex

            while characterIndex < text.endIndex {
                let next = text.index(after: characterIndex)
                let character = text[characterIndex..<next]
                let sourceRange = sourceOffset..<(sourceOffset + character.utf8.count)
                UnicodeNormalization.normalizeNFC(
                    character.unicodeScalars,
                    using: &normalizationBuffer
                )
                let scalars = normalizationBuffer.normalized
                if runScript == nil {
                    runScript = scalars.lazy
                        .map(UnicodeScript.script)
                        .first(where: \.isStrong)
                }
                let glyphs = scalars.map {
                    sfnt.glyphID(for: $0, in: face) ?? .init(rawValue: 0)
                }
                nominalClusters.append((
                    sourceRange: sourceRange,
                    scalars: scalars,
                    glyphs: glyphs.map(\.rawValue)
                ))
                for glyph in glyphs {
                    workspace.glyphs.append(.init(
                        id: glyph,
                        sourceRange: sourceRange,
                        lookupIndex: nil,
                        feature: nil
                    ))
                }
                sourceOffset = sourceRange.upperBound
                characterIndex = next
            }

            if let substitutions = sfnt.glyphSubstitution(in: face) {
                let plan = substitutions.shapingPlan(
                    script: (runScript ?? .common).tag
                )
                OpenTypeShaper.apply(
                    plan,
                    to: &workspace.glyphs
                )
            }

            let sourceBytes = Array(text.utf8)
            var result: [ShapingDebugInfo] = []
            result.reserveCapacity(workspace.glyphs.count)
            for glyphIndex in 0..<workspace.glyphs.count {
                let glyph = workspace.glyphs[glyphIndex]
                let clusters = nominalClusters.filter {
                    $0.sourceRange.lowerBound < glyph.sourceRange.upperBound
                        && glyph.sourceRange.lowerBound < $0.sourceRange.upperBound
                }
                result.append(.init(
                    source: String(
                        decoding: sourceBytes[glyph.sourceRange],
                        as: UTF8.self
                    ),
                    sourceRange: glyph.sourceRange,
                    normalizedScalars: clusters.flatMap(\.scalars),
                    nominalGlyphIDs: clusters.flatMap(\.glyphs),
                    shapedGlyphIDs: [glyph.id.rawValue],
                    feature: glyph.feature.map(Self.tagString),
                    lookupIndex: glyph.lookupIndex
                ))
            }
            return result
        }

        private func loadDebugFace(bytes: [UInt8], id: String) throws -> SFNT.Face {
            try state.withLock { state in
                if let face = state.debugFaces[id] {
                    return face
                }
                let face = try sfnt.register(bytes: bytes)
                state.debugFaces[id] = face
                return face
            }
        }

        private static func tagString(_ tag: UInt32) -> String {
            String(decoding: [
                UInt8(truncatingIfNeeded: tag >> 24),
                UInt8(truncatingIfNeeded: tag >> 16),
                UInt8(truncatingIfNeeded: tag >> 8),
                UInt8(truncatingIfNeeded: tag)
            ], as: UTF8.self)
        }
    }
}
