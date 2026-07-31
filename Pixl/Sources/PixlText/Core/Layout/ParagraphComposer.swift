enum ParagraphComposer {
    static func positionParagraphs(
        sourceUTF8Count: Int,
        maximumWidth: Float,
        lineHeight: LineHeight,
        lineSpacing: Float,
        paragraphSpacing: Float,
        glyphs: Span<ShapingGlyph>,
        runs: Span<GlyphRun>,
        opportunities: Span<LineBreakOpportunity>,
        units: Span<LineBreakUnit>,
        registry: borrowing SFNT.Registry,
        workspace: inout LineLayoutWorkspace
    ) throws {
        guard lineSpacing >= 0,
              lineSpacing.isFinite,
              paragraphSpacing >= 0,
              paragraphSpacing.isFinite
        else {
            throw LineLayoutError.invalidInput
        }

        workspace.removeAll()
        var next: LineStart? = try LineComposer.start(
            sourceUTF8Count: sourceUTF8Count,
            glyphs: glyphs,
            runs: runs,
            opportunities: opportunities
        )
        var lineTop: Float = 0
        var paragraphLineStart = 0
        var paragraphSourceStart = 0
        var paragraphBounds: PositionedLine.Bounds?
        var paragraphRenderBounds: PositionedLine.Bounds?
        var firstBaselineY: Float = 0

        while let lineStart = next {
            let composition = try LineComposer.positionLine(
                from: lineStart,
                lineTop: lineTop,
                sourceUTF8Count: sourceUTF8Count,
                maximumWidth: maximumWidth,
                lineHeight: lineHeight,
                glyphs: glyphs,
                runs: runs,
                opportunities: opportunities,
                units: units,
                registry: registry,
                workspace: &workspace
            )
            let line = composition.line
            let lineIndex = workspace.lines.count
            if lineIndex == paragraphLineStart {
                firstBaselineY = line.baselineY
            }
            paragraphBounds = union(paragraphBounds, documentBounds(
                line.lineBounds,
                baselineY: line.baselineY
            ))
            if let renderBounds = line.renderBounds {
                paragraphRenderBounds = union(paragraphRenderBounds, documentBounds(
                    renderBounds,
                    baselineY: line.baselineY
                ))
            }
            workspace.lines.append(line)
            next = composition.next

            let endsParagraph = line.breakKind == .mandatory || next == nil
            if endsParagraph {
                workspace.paragraphs.append(.init(
                    lineRange: paragraphLineStart..<(lineIndex + 1),
                    consumedSourceRange: paragraphSourceStart..<line.consumedSourceRange.upperBound,
                    bounds: paragraphBounds!,
                    renderBounds: paragraphRenderBounds,
                    firstBaselineY: firstBaselineY,
                    lastBaselineY: line.baselineY
                ))
                paragraphLineStart = lineIndex + 1
                paragraphSourceStart = line.consumedSourceRange.upperBound
                paragraphBounds = nil
                paragraphRenderBounds = nil
            }

            guard next != nil else { break }
            lineTop += line.lineBounds.height
            lineTop += endsParagraph ? paragraphSpacing : lineSpacing
        }
    }

    private static func documentBounds(
        _ bounds: PositionedLine.Bounds,
        baselineY: Float
    ) -> PositionedLine.Bounds {
        .init(
            x: bounds.x,
            y: baselineY + bounds.y,
            width: bounds.width,
            height: bounds.height
        )
    }

    private static func union(
        _ lhs: PositionedLine.Bounds?,
        _ rhs: PositionedLine.Bounds
    ) -> PositionedLine.Bounds {
        guard let lhs else { return rhs }
        let minX = min(lhs.x, rhs.x)
        let minY = min(lhs.y, rhs.y)
        let maxX = max(lhs.x + lhs.width, rhs.x + rhs.width)
        let maxY = max(lhs.y + lhs.height, rhs.y + rhs.height)
        return .init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
