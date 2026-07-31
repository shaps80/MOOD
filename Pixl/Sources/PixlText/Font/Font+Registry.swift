import PixlSynchronization

extension Font {
    final class Registry: @unchecked Sendable {
        private struct State {
            var systemFace: SFNT.Face?
            var debugFaces: [String: SFNT.Face] = [:]
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
            var workspace = ShapingScratch(minimumGlyphCapacity: text.utf8.count)
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
            font: RunDebugInfo.FontInput,
            overrides: [RunDebugInfo.Input],
            constraints: LayoutConstraints,
            lineHeight debugLineHeight: RunDebugInfo.LineHeight,
            paragraphStyles: [ParagraphStyle]
        ) throws -> RunDebugInfo {
            let baseFace = try loadDebugFace(bytes: font.fontBytes, id: font.fontID)
            let baseMetrics = baseFace.metrics.scaled(to: font.font.descriptor.size)
            var substitutionPlans: [OpenTypeShapingPlan] = []
            var positioningPlans: [OpenTypePositioningPlan] = []
            var workspace = ShapingWorkspace(
                minimumGlyphCapacity: text.utf8.count,
                minimumRunCapacity: overrides.count * 2 + 1
            )
            try forEachResolvedRunInput(
                sourceCount: text.utf8.count,
                font: font,
                overrides: overrides
            ) { sourceRange, input in
                let face = try loadDebugFace(
                    bytes: input.fontBytes,
                    id: input.fontID
                )
                let script = Self.script(in: text, sourceRange: sourceRange)
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
                workspace.inputRuns.append(.init(
                    sourceRange: sourceRange,
                    face: face,
                    size: input.font.descriptor.size,
                    direction: input.direction == .leftToRight
                        ? .leftToRight
                        : .rightToLeft,
                    script: script,
                    language: nil,
                    substitutionPlanIndex: substitutionPlanIndex,
                    positioningPlanIndex: positioningPlanIndex
                ))
            }

            try substitutionPlans.withUnsafeBufferPointer { substitutions in
                try positioningPlans.withUnsafeBufferPointer { positioning in
                    try RunShaper.shape(
                        text,
                        substitutionPlans: unsafe Span(_unsafeElements: substitutions),
                        positioningPlans: unsafe Span(_unsafeElements: positioning),
                        registry: sfnt,
                        workspace: &workspace
                    )
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
                        fontName: Self.fontInput(
                            at: run.sourceRange.lowerBound,
                            font: font,
                            overrides: overrides
                        ).fontName,
                        size: run.size,
                        direction: run.direction == .leftToRight
                            ? .leftToRight
                            : .rightToLeft,
                        script: Self.tagString(run.script.tag)
                    ))
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
                    let kind: RunDebugInfo.Break.Kind = switch opportunity.kind {
                    case .allowed: .allowed
                    case .softHyphen: .softHyphen
                    case .mandatory: .mandatory
                    }
                    debugBreaks.append(.init(
                        sourceOffset: opportunity.sourceOffset,
                        kind: kind
                    ))
                }
            }

            var lineWorkspace = LineLayoutWorkspace(
                minimumGlyphCapacity: workspace.glyphs.count
            )
            let lineHeight: LineHeight = switch debugLineHeight {
            case .natural: .natural
            case .multiple(let value): .multiple(value)
            case .atLeast(let value): .atLeast(value)
            case .exactly(let value): .exactly(value)
            }
            var debugGlyphs: [RunDebugInfo.Glyph] = []
            var debugLines: [RunDebugInfo.Line] = []
            var debugParagraphs: [RunDebugInfo.Paragraph] = []
            var positionedLayout: PositionedLayout?
            try workspace.runs.withSpan { runs in
                try workspace.glyphs.withSpan { glyphs in
                    try lineBreakWorkspace.opportunities.withSpan { opportunities in
                        try lineBreakWorkspace.units.withSpan { units in
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
                                    registry: sfnt,
                                    workspace: &lineWorkspace
                                )
                            }
                            lineWorkspace.lines.withSpan { lines in
                                lineWorkspace.positions.withSpan { positions in
                                    var paragraphIndex = 0
                                    for lineIndex in lines.indices {
                                        let positionedLine = lines[lineIndex]
                                        while paragraphIndex + 1 < lineWorkspace.paragraphs.count,
                                              lineIndex >= lineWorkspace.paragraphs[paragraphIndex]
                                                .lineRange.upperBound {
                                            paragraphIndex += 1
                                        }
                                        var runIndex = 0
                                        while runIndex < runs.count,
                                              positionedLine.consumedGlyphRange.lowerBound
                                                >= runs[runIndex].glyphRange.upperBound {
                                            runIndex += 1
                                        }
                                        for glyphIndex in positionedLine.consumedGlyphRange {
                                            while runIndex < runs.count,
                                                  glyphIndex >= runs[runIndex].glyphRange.upperBound {
                                                runIndex += 1
                                            }
                                            let run = runs[runIndex]
                                            let glyph = glyphs[glyphIndex]
                                            let position = positions[
                                                positionedLine.positionRange.lowerBound
                                                    + glyphIndex
                                                    - positionedLine.consumedGlyphRange.lowerBound
                                            ]
                                            let metrics = run.face.metrics.scaled(to: run.size)
                                            let scale = run.size / Float(run.face.metrics.unitsPerEm)
                                            let advance = Float(
                                                glyph.nominalXAdvance + glyph.xAdvance
                                            ) * scale
                                            let rawRenderBounds = sfnt.renderBounds(
                                                for: glyph.id,
                                                in: run.face
                                            )
                                            debugGlyphs.append(.init(
                                                lineIndex: lineIndex,
                                                runIndex: runIndex,
                                                glyphID: glyph.id.rawValue,
                                                sourceRange: glyph.sourceRange,
                                                advance: advance,
                                                typographicBounds: .init(
                                                    x: positionedLine.originX + position.x,
                                                    y: -metrics.ascent,
                                                    width: advance,
                                                    height: metrics.ascent + metrics.descent
                                                ),
                                                renderBounds: rawRenderBounds.map {
                                                    .init(
                                                        x: positionedLine.originX
                                                            + position.x
                                                            + Float($0.xMin) * scale,
                                                        y: position.y - Float($0.yMax) * scale,
                                                        width: Float($0.xMax - $0.xMin) * scale,
                                                        height: Float($0.yMax - $0.yMin) * scale
                                                    )
                                                }
                                            ))
                                        }
                                        debugLines.append(Self.debugLine(
                                            positionedLine,
                                            maximumWidth: Self.availableWidth(
                                                constraints.width,
                                                style: paragraphStyles[paragraphIndex],
                                                isFirstLine: lineIndex
                                                    == lineWorkspace.paragraphs[paragraphIndex]
                                                        .lineRange.lowerBound
                                            ),
                                            availableX: Self.availableX(
                                                style: paragraphStyles[paragraphIndex],
                                                isFirstLine: lineIndex
                                                    == lineWorkspace.paragraphs[paragraphIndex]
                                                        .lineRange.lowerBound
                                            )
                                        ))
                                    }
                                }
                            }
                            lineWorkspace.paragraphs.withSpan { paragraphs in
                                debugParagraphs.reserveCapacity(paragraphs.count)
                                for index in paragraphs.indices {
                                    let paragraph = paragraphs[index]
                                    debugParagraphs.append(.init(
                                        source: String(
                                            decoding: sourceBytes[paragraph.consumedSourceRange],
                                            as: UTF8.self
                                        ),
                                        sourceRange: paragraph.consumedSourceRange,
                                        lineRange: paragraph.lineRange,
                                        bounds: .init(
                                            x: paragraph.bounds.x,
                                            y: paragraph.bounds.y,
                                            width: paragraph.bounds.width,
                                            height: paragraph.bounds.height
                                        ),
                                        renderBounds: paragraph.renderBounds.map {
                                            .init(
                                                x: $0.x,
                                                y: $0.y,
                                                width: $0.width,
                                                height: $0.height
                                            )
                                        },
                                        firstBaselineY: paragraph.firstBaselineY,
                                        lastBaselineY: paragraph.lastBaselineY
                                    ))
                                }
                            }
                        }
                    }
                }
            }
            let debugWords = Self.debugWords(
                sourceBytes: sourceBytes,
                glyphs: debugGlyphs,
                lines: debugLines,
                breaks: debugBreaks
            )
            guard let positionedLayout else {
                throw LineLayoutError.invalidInput
            }
            return .init(
                runs: debugRuns,
                glyphs: debugGlyphs,
                words: debugWords,
                breaks: debugBreaks,
                lines: debugLines,
                paragraphs: debugParagraphs,
                status: positionedLayout.status,
                bounds: .init(
                    x: positionedLayout.bounds.x,
                    y: positionedLayout.bounds.y,
                    width: positionedLayout.bounds.width,
                    height: positionedLayout.bounds.height
                ),
                reservedLineCount: positionedLayout.reservedLineCount
            )
        }

        private func forEachResolvedRunInput(
            sourceCount: Int,
            font: RunDebugInfo.FontInput,
            overrides: [RunDebugInfo.Input],
            _ body: (Range<Int>, RunDebugInfo.FontInput) throws -> Void
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

        private static func fontInput(
            at sourceOffset: Int,
            font: RunDebugInfo.FontInput,
            overrides: [RunDebugInfo.Input]
        ) -> RunDebugInfo.FontInput {
            for override in overrides where override.sourceRange.contains(sourceOffset) {
                return override.font
            }
            return font
        }

        private static func debugWords(
            sourceBytes: [UInt8],
            glyphs: [RunDebugInfo.Glyph],
            lines: [RunDebugInfo.Line],
            breaks: [RunDebugInfo.Break]
        ) -> [RunDebugInfo.Word] {
            var result: [RunDebugInfo.Word] = []
            var breakIndex = 0
            var glyphIndex = 0
            for lineIndex in lines.indices {
                let line = lines[lineIndex]
                var sourceStart = line.consumedSourceRange.lowerBound
                while breakIndex < breaks.count,
                      breaks[breakIndex].sourceOffset <= sourceStart {
                    breakIndex += 1
                }
                while breakIndex < breaks.count,
                      breaks[breakIndex].sourceOffset <= line.consumedSourceRange.upperBound {
                    let sourceEnd = breaks[breakIndex].sourceOffset
                    var visibleEnd = sourceEnd
                    while visibleEnd > sourceStart,
                          isDebugWhitespace(sourceBytes[visibleEnd - 1]) {
                        visibleEnd -= 1
                    }
                    if visibleEnd > sourceStart {
                        while glyphIndex < glyphs.count,
                              glyphs[glyphIndex].sourceRange.upperBound <= sourceStart {
                            glyphIndex += 1
                        }
                        var scan = glyphIndex
                        var minX = Float.greatestFiniteMagnitude
                        var maxX = -Float.greatestFiniteMagnitude
                        while scan < glyphs.count,
                              glyphs[scan].lineIndex == lineIndex,
                              glyphs[scan].sourceRange.lowerBound < visibleEnd {
                            let bounds = glyphs[scan].typographicBounds
                            minX = min(minX, bounds.x)
                            maxX = max(maxX, bounds.x + bounds.width)
                            scan += 1
                        }
                        if minX <= maxX {
                            result.append(.init(
                                lineIndex: lineIndex,
                                source: String(
                                    decoding: sourceBytes[sourceStart..<visibleEnd],
                                    as: UTF8.self
                                ),
                                sourceRange: sourceStart..<visibleEnd,
                                bounds: .init(
                                    x: minX,
                                    y: line.typographicBounds.y,
                                    width: maxX - minX,
                                    height: line.typographicBounds.height
                                )
                            ))
                        }
                    }
                    sourceStart = sourceEnd
                    breakIndex += 1
                }
            }
            return result
        }

        private static func isDebugWhitespace(_ byte: UInt8) -> Bool {
            byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
        }

        private static func debugLine(
            _ line: PositionedLine,
            maximumWidth: Float,
            availableX: Float
        ) -> RunDebugInfo.Line {
            let breakKind: RunDebugInfo.Break.Kind = switch line.breakKind {
            case .allowed: .allowed
            case .softHyphen: .softHyphen
            case .mandatory: .mandatory
            }
            return .init(
                availableX: availableX,
                maximumWidth: maximumWidth,
                consumedSourceRange: line.consumedSourceRange,
                consumedGlyphRange: line.consumedGlyphRange,
                visibleGlyphRange: line.visibleGlyphRange,
                breakKind: breakKind,
                advance: line.advance,
                ascent: line.ascent,
                descent: line.descent,
                leading: line.leading,
                naturalAbove: line.naturalAbove,
                naturalBelow: line.naturalBelow,
                baselineY: line.baselineY,
                baselineOffset: line.baselineOffset,
                typographicBounds: .init(
                    x: line.typographicBounds.x,
                    y: line.typographicBounds.y,
                    width: line.typographicBounds.width,
                    height: line.typographicBounds.height
                ),
                lineBounds: .init(
                    x: line.lineBounds.x,
                    y: line.lineBounds.y,
                    width: line.lineBounds.width,
                    height: line.lineBounds.height
                ),
                renderBounds: line.renderBounds.map {
                    .init(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
                }
            )
        }

        private static func availableX(
            style: ParagraphStyle,
            isFirstLine: Bool
        ) -> Float {
            style.indentation.leading
                + (isFirstLine && style.alignment == .leading
                    ? style.indentation.firstLine
                    : 0)
        }

        private static func availableWidth(
            _ maximumWidth: Float,
            style: ParagraphStyle,
            isFirstLine: Bool
        ) -> Float {
            max(
                0,
                maximumWidth
                    - availableX(style: style, isFirstLine: isFirstLine)
                    - style.indentation.trailing
                    - (isFirstLine && style.alignment == .trailing
                        ? style.indentation.firstLine
                        : 0)
            )
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
