import PixlSynchronization

extension Font {
    final class Registry: @unchecked Sendable {
        private struct State {
            var systemFace: SFNT.Face?
            var facesByID: [String: SFNT.Face] = [:]
        }

        enum Error: Swift.Error {
            case systemFontNotRegistered
            case invalidFontOverrideRanges
        }

        static let shared = Registry()

        private let state = CriticalState(State())
        private let sfnt = SFNT.Registry()

        private init() {}

        func face(for descriptor: Descriptor) throws -> SFNT.Face {
            switch descriptor.source {
            case .system:
                let base = try state.withLock { state in
                    guard let systemFace = state.systemFace else {
                        throw Error.systemFontNotRegistered
                    }
                    return systemFace
                }
                return resolvedFace(base, descriptor: descriptor)
            }
        }

        func registerSystemFont(bytes: [UInt8]) throws {
            try state.withLock { state in
                guard state.systemFace == nil else { return }
                state.systemFace = try sfnt.register(bytes: bytes)
            }
        }

        func layoutDebugInfo(
            in text: String,
            font: LayoutDebugInfo.FontInput,
            overrides: [LayoutDebugInfo.Input],
            constraints: LayoutConstraints,
            lineHeight debugLineHeight: LayoutDebugInfo.LineHeight,
            paragraphStyles: [ParagraphStyle],
            session: LayoutDebugSession
        ) throws -> LayoutDebugInfo {
            let baseFace = resolvedFace(
                try loadFace(bytes: font.fontBytes, id: font.fontID),
                descriptor: font.font.descriptor
            )
            let baseMetrics = baseFace.metrics.scaled(to: font.font.descriptor.size)

            try forEachResolvedRunInput(
                sourceCount: text.utf8.count,
                font: font,
                overrides: overrides
            ) { sourceRange, input in
                let face = resolvedFace(
                    try loadFace(bytes: input.fontBytes, id: input.fontID),
                    descriptor: input.font.descriptor
                )
                let script = Self.script(in: text, sourceRange: sourceRange)
                let substitutionPlanIndex = sfnt.glyphSubstitution(in: face).map { source in
                    session.substitutionPlanIndex(
                        for: face,
                        script: script,
                        language: nil,
                        source: source
                    )
                }
                let positioningPlanIndex = sfnt.glyphPositioning(in: face).map { source in
                    session.positioningPlanIndex(
                        for: face,
                        script: script,
                        language: nil,
                        source: source,
                        variationStore: sfnt.glyphDefinition(in: face)?.itemVariationStore
                    )
                }
                session.shaping.inputRuns.append(.init(
                    sourceRange: sourceRange,
                    face: face,
                    size: input.font.descriptor.size,
                    direction: input.direction == .leftToRight ? .leftToRight : .rightToLeft,
                    script: script,
                    language: nil,
                    substitutionPlanIndex: substitutionPlanIndex,
                    positioningPlanIndex: positioningPlanIndex
                ))
            }
            try session.substitutionPlans.withUnsafeBufferPointer { substitutions in
                try session.positioningPlans.withUnsafeBufferPointer { positioning in
                    try RunShaper.shape(
                        text,
                        substitutionPlans: unsafe Span(_unsafeElements: substitutions),
                        positioningPlans: unsafe Span(_unsafeElements: positioning),
                        registry: sfnt,
                        workspace: &session.shaping
                    )
                }
            }
            paragraphStyles.withUnsafeBufferPointer { styles in
                LineBreaker.findOpportunities(
                    in: text,
                    styles: unsafe Span(_unsafeElements: styles),
                    workspace: &session.lineBreaking
                )
            }

            let lineHeight: LineHeight = switch debugLineHeight {
            case .natural: .natural
            case .multiple(let value): .multiple(value)
            case .atLeast(let value): .atLeast(value)
            case .exactly(let value): .exactly(value)
            }
            var positionedLayout: PositionedLayout?
            try session.shaping.runs.withSpan { runs in
                try session.shaping.glyphs.withSpan { glyphs in
                    try session.lineBreaking.opportunities.withSpan { opportunities in
                        try session.lineBreaking.units.withSpan { units in
                            try session.shaping.insertionGlyphs.withSpan { insertionGlyphs in
                                try paragraphStyles.withUnsafeBufferPointer { styles in
                                    positionedLayout = try ParagraphComposer.positionParagraphs(
                                        sourceUTF8Count: text.utf8.count,
                                        constraints: constraints,
                                        lineHeight: lineHeight,
                                        baseMetrics: baseMetrics,
                                        styles: unsafe Span(_unsafeElements: styles),
                                        glyphs: glyphs,
                                        runs: runs,
                                        opportunities: opportunities,
                                        units: units,
                                        insertionGlyphs: insertionGlyphs,
                                        registry: sfnt,
                                        workspace: &session.lineLayout
                                    )
                                }
                            }
                        }
                    }
                }
            }
            guard let positionedLayout else { throw LineLayoutError.invalidInput }

            let runBounds = runBounds(session: session)
            var debugRuns: [LayoutDebugInfo.Run] = []
            debugRuns.reserveCapacity(session.shaping.runs.count)
            session.shaping.runs.withSpan { runs in
                for index in runs.indices {
                    guard let bounds = runBounds[index] else { continue }
                    debugRuns.append(.init(
                        sourceRange: runs[index].sourceRange,
                        bounds: bounds
                    ))
                }
            }

            var debugParagraphs: [LayoutDebugInfo.Paragraph] = []
            debugParagraphs.reserveCapacity(session.lineLayout.paragraphs.count)
            session.lineLayout.paragraphs.withSpan { paragraphs in
                for index in paragraphs.indices {
                    let paragraph = paragraphs[index]
                    debugParagraphs.append(.init(
                        sourceRange: paragraph.consumedSourceRange,
                        bounds: Self.debugBounds(paragraph.bounds)
                    ))
                }
            }
            return .init(
                runs: debugRuns,
                paragraphs: debugParagraphs,
                bounds: Self.debugBounds(positionedLayout.bounds)
            )
        }

        private func runBounds(
            session: LayoutDebugSession
        ) -> [LayoutDebugInfo.Bounds?] {
            var result = [LayoutDebugInfo.Bounds?](
                repeating: nil,
                count: session.shaping.runs.count
            )
            session.shaping.runs.withSpan { runs in
                session.shaping.glyphs.withSpan { glyphs in
                    session.lineLayout.lines.withSpan { lines in
                        session.lineLayout.positions.withSpan { positions in
                            for lineIndex in lines.indices {
                                let line = lines[lineIndex]
                                var runIndex = 0
                                while runIndex < runs.count,
                                      line.visibleGlyphRange.lowerBound >= runs[runIndex]
                                        .glyphRange.upperBound {
                                    runIndex += 1
                                }
                                for glyphIndex in line.visibleGlyphRange {
                                    while runIndex < runs.count,
                                          glyphIndex >= runs[runIndex].glyphRange.upperBound {
                                        runIndex += 1
                                    }
                                    guard runIndex < runs.count else { break }
                                    let run = runs[runIndex]
                                    let glyph = glyphs[glyphIndex]
                                    let position = positions[
                                        line.positionRange.lowerBound
                                            + glyphIndex
                                            - line.consumedGlyphRange.lowerBound
                                    ]
                                    let metrics = run.face.metrics.scaled(to: run.size)
                                    let scale = run.size / Float(run.face.metrics.unitsPerEm)
                                    let advance = Float(glyph.nominalXAdvance + glyph.xAdvance) * scale
                                    let bounds = LayoutDebugInfo.Bounds(
                                        x: line.originX + position.x,
                                        y: line.baselineY - metrics.ascent,
                                        width: advance,
                                        height: metrics.ascent + metrics.descent
                                    )
                                    result[runIndex] = Self.union(result[runIndex], bounds)
                                }
                            }
                        }
                    }
                }
            }
            return result
        }

        private func forEachResolvedRunInput(
            sourceCount: Int,
            font: LayoutDebugInfo.FontInput,
            overrides: [LayoutDebugInfo.Input],
            _ body: (Range<Int>, LayoutDebugInfo.FontInput) throws -> Void
        ) throws {
            guard sourceCount > 0 else {
                guard overrides.isEmpty else { throw Error.invalidFontOverrideRanges }
                return
            }
            var sourceOffset = 0
            for override in overrides {
                let range = override.sourceRange
                guard !range.isEmpty,
                      range.lowerBound >= sourceOffset,
                      range.upperBound <= sourceCount
                else {
                    throw Error.invalidFontOverrideRanges
                }
                if sourceOffset < range.lowerBound {
                    try body(sourceOffset..<range.lowerBound, font)
                }
                try body(range, override.font)
                sourceOffset = range.upperBound
            }
            if sourceOffset < sourceCount {
                try body(sourceOffset..<sourceCount, font)
            }
        }

        private static func debugBounds(
            _ bounds: PositionedLine.Bounds
        ) -> LayoutDebugInfo.Bounds {
            .init(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
        }

        private static func union(
            _ lhs: LayoutDebugInfo.Bounds?,
            _ rhs: LayoutDebugInfo.Bounds
        ) -> LayoutDebugInfo.Bounds {
            guard let lhs else { return rhs }
            let minX = min(lhs.x, rhs.x)
            let minY = min(lhs.y, rhs.y)
            let maxX = max(lhs.x + lhs.width, rhs.x + rhs.width)
            let maxY = max(lhs.y + lhs.height, rhs.y + rhs.height)
            return .init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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

        private func loadFace(bytes: [UInt8], id: String) throws -> SFNT.Face {
            try state.withLock { state in
                if let face = state.facesByID[id] { return face }
                let face = try sfnt.register(bytes: bytes)
                state.facesByID[id] = face
                return face
            }
        }

        func variationAxes(fontBytes: [UInt8], fontID: String) throws -> [Axis] {
            let face = try loadFace(bytes: fontBytes, id: fontID)
            return sfnt.variationAxes(in: face).map {
                .init(
                    tag: Self.tagString($0.tag),
                    minimum: $0.minimum,
                    defaultValue: $0.defaultValue,
                    maximum: $0.maximum
                )
            }
        }

        func namedVariationInstances(
            fontBytes: [UInt8],
            fontID: String
        ) throws -> [NamedInstance] {
            let face = try loadFace(bytes: fontBytes, id: fontID)
            return sfnt.namedVariationInstances(in: face).map {
                .init(nameID: $0.nameID, coordinates: $0.coordinates)
            }
        }

        private func resolvedFace(_ base: SFNT.Face, descriptor: Descriptor) -> SFNT.Face {
            let axes = sfnt.variationAxes(in: base)
            guard !axes.isEmpty else { return base }
            var settings = descriptor.variations.map { ($0.tag, $0.value) }
            if axes.contains(where: { $0.tag == 0x7767_6874 }),
               !settings.contains(where: { $0.0 == 0x7767_6874 }) {
                settings.append((0x7767_6874, Self.weightValue(descriptor.weight)))
            }
            if descriptor.slant == .italic {
                if axes.contains(where: { $0.tag == 0x6974_616C }),
                   !settings.contains(where: { $0.0 == 0x6974_616C }) {
                    settings.append((0x6974_616C, 1))
                } else if let slant = axes.first(where: { $0.tag == 0x736C_6E74 }),
                          !settings.contains(where: { $0.0 == 0x736C_6E74 }) {
                    settings.append((0x736C_6E74, slant.minimum))
                }
            }
            return sfnt.instance(of: base, settings: settings) ?? base
        }

        private static func weightValue(_ weight: Weight) -> Float {
            switch weight {
            case .ultraLight: 100
            case .thin: 200
            case .light: 300
            case .regular: 400
            case .medium: 500
            case .semibold: 600
            case .bold: 700
            case .heavy: 800
            case .black: 900
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
