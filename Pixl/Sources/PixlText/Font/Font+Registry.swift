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
                        feature: nil,
                        nominalXAdvance: Int32(
                            sfnt.advanceInFontUnits(for: glyph, in: face) ?? 0
                        )
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
                    glyphDefinition: sfnt.glyphDefinition(in: face),
                    workspace: &workspace
                )
            }
            for glyphIndex in 0..<workspace.glyphs.count {
                workspace.glyphs[glyphIndex].nominalXAdvance = Int32(
                    sfnt.advanceInFontUnits(
                        for: workspace.glyphs[glyphIndex].id,
                        in: face
                    ) ?? 0
                )
            }
            if let positioning = sfnt.glyphPositioning(in: face) {
                let plan = positioning.positioningPlan(
                    script: (runScript ?? .common).tag
                )
                OpenTypePositioner.apply(
                    plan,
                    glyphDefinition: sfnt.glyphDefinition(in: face),
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
                    xPlacement: glyph.xPlacement,
                    yPlacement: glyph.yPlacement,
                    xAdvance: glyph.xAdvance,
                    yAdvance: glyph.yAdvance,
                    feature: glyph.feature.map(Self.tagString),
                    lookupIndex: glyph.lookupIndex
                ))
            }
            return result
        }

        func runDebugInfo(
            in text: String,
            inputs: [RunDebugInfo.Input]
        ) throws -> RunDebugInfo {
            var textRuns: [TextRun] = []
            var substitutionPlans: [OpenTypeShapingPlan] = []
            var positioningPlans: [OpenTypePositioningPlan] = []
            textRuns.reserveCapacity(inputs.count)
            for input in inputs {
                let face = try loadDebugFace(bytes: input.fontBytes, id: input.fontID)
                let script = Self.script(in: text, sourceRange: input.sourceRange)
                let substitutionPlanIndex = sfnt.glyphSubstitution(in: face).map {
                    let index = substitutionPlans.count
                    substitutionPlans.append($0.shapingPlan(script: script.tag))
                    return index
                }
                let positioningPlanIndex = sfnt.glyphPositioning(in: face).map {
                    let index = positioningPlans.count
                    positioningPlans.append($0.positioningPlan(script: script.tag))
                    return index
                }
                textRuns.append(.init(
                    sourceRange: input.sourceRange,
                    face: face,
                    size: input.font.descriptor.size,
                    direction: input.direction == .leftToRight ? .leftToRight : .rightToLeft,
                    script: script,
                    language: nil,
                    substitutionPlanIndex: substitutionPlanIndex,
                    positioningPlanIndex: positioningPlanIndex
                ))
            }

            var workspace = RunShapingWorkspace(
                minimumGlyphCapacity: text.utf8.count,
                minimumRunCapacity: inputs.count
            )
            try textRuns.withUnsafeBufferPointer { buffer in
                try substitutionPlans.withUnsafeBufferPointer { substitutions in
                    try positioningPlans.withUnsafeBufferPointer { positioning in
                        try RunShaper.shape(
                            text,
                            runs: unsafe Span(_unsafeElements: buffer),
                            substitutionPlans: unsafe Span(_unsafeElements: substitutions),
                            positioningPlans: unsafe Span(_unsafeElements: positioning),
                            registry: sfnt,
                            workspace: &workspace
                        )
                    }
                }
            }

            var debugRuns: [RunDebugInfo.Run] = []
            let sourceBytes = Array(text.utf8)
            debugRuns.reserveCapacity(workspace.runs.count)
            workspace.runs.withSpan { runs in
                for index in runs.indices {
                    let run = runs[index]
                    debugRuns.append(.init(
                        source: String(decoding: sourceBytes[run.sourceRange], as: UTF8.self),
                        sourceRange: run.sourceRange,
                        glyphRange: run.glyphRange,
                        fontName: inputs[index].fontName,
                        size: run.size,
                        direction: run.direction == .leftToRight
                            ? .leftToRight
                            : .rightToLeft,
                        script: Self.tagString(run.script.tag)
                    ))
                }
            }

            var debugGlyphs: [RunDebugInfo.Glyph] = []
            debugGlyphs.reserveCapacity(workspace.glyphs.count)
            var x: Float = 0
            workspace.runs.withSpan { runs in
                workspace.glyphs.withSpan { glyphs in
                    for runIndex in runs.indices {
                        let run = runs[runIndex]
                        let metrics = run.face.metrics.scaled(to: run.size)
                        let scale = run.size / Float(run.face.metrics.unitsPerEm)
                        for glyphIndex in run.glyphRange {
                            let glyph = glyphs[glyphIndex]
                            let advance = Float(glyph.nominalXAdvance + glyph.xAdvance) * scale
                            let rawRenderBounds = sfnt.renderBounds(for: glyph.id, in: run.face)
                            debugGlyphs.append(.init(
                                runIndex: runIndex,
                                glyphID: glyph.id.rawValue,
                                sourceRange: glyph.sourceRange,
                                advance: advance,
                                typographicBounds: .init(
                                    x: x,
                                    y: -metrics.ascent,
                                    width: advance,
                                    height: metrics.ascent + metrics.descent
                                ),
                                renderBounds: rawRenderBounds.map {
                                    .init(
                                        x: x + Float(Int32($0.xMin) + glyph.xPlacement) * scale,
                                        y: -Float(Int32($0.yMax) + glyph.yPlacement) * scale,
                                        width: Float($0.xMax - $0.xMin) * scale,
                                        height: Float($0.yMax - $0.yMin) * scale
                                    )
                                }
                            ))
                            x += advance
                        }
                    }
                }
            }

            var lineBreakWorkspace = LineBreakWorkspace(
                minimumScalarCapacity: text.unicodeScalars.count,
                minimumOpportunityCapacity: text.utf8.count / 4
            )
            LineBreaker.findOpportunities(in: text, workspace: &lineBreakWorkspace)
            var debugBreaks: [RunDebugInfo.Break] = []
            debugBreaks.reserveCapacity(lineBreakWorkspace.opportunities.count)
            lineBreakWorkspace.opportunities.withSpan { opportunities in
                for index in opportunities.indices {
                    let opportunity = opportunities[index]
                    debugBreaks.append(.init(
                        sourceOffset: opportunity.sourceOffset,
                        kind: opportunity.kind == .allowed ? .allowed : .mandatory
                    ))
                }
            }
            return .init(runs: debugRuns, glyphs: debugGlyphs, breaks: debugBreaks)
        }

        private static func script(
            in text: String,
            sourceRange: Range<Int>
        ) -> UnicodeScript {
            let utf8 = text.utf8
            let lowerUTF8 = utf8.index(utf8.startIndex, offsetBy: sourceRange.lowerBound)
            let upperUTF8 = utf8.index(lowerUTF8, offsetBy: sourceRange.count)
            guard let lower = lowerUTF8.samePosition(in: text),
                  let upper = upperUTF8.samePosition(in: text)
            else {
                return .common
            }
            return text[lower..<upper].unicodeScalars.lazy
                .map(UnicodeScript.script)
                .first(where: \.isStrong) ?? .common
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
