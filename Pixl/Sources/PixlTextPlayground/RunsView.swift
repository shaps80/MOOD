import SwiftUI
import PixlText

struct RunsView: View {
    private static let text = """
    Hello, world! Line breaking finds every legal opportunity before layout chooses which words fit. Explicit newlines remain mandatory.
    A second paragraph gives us enough text to exercise wrapping across several future lines.
    """
    private static let origin = CGPoint(x: 40, y: 170)
    private static let lineWidth: Float = 520
    private static let colors: [Color] = [.cyan, .orange]

    @State private var isShowing: Bool = true
    @State private var hoveredGlyph: Int?

    private let information: Result<Font.RunDebugInfo, Error>

    init(font: PlaygroundFont) {
        information = Result {
            let secondFont = font.path == PlaygroundFont.zapfino.path
                ? PlaygroundFont.senilita
                : PlaygroundFont.zapfino
            let split = "Hello, world! Line breaking finds every legal opportunity ".utf8.count
            return try Font.runDebugInfo(
                in: Self.text,
                runs: [
                    .init(
                        sourceRange: 0..<split,
                        font: .system(size: 32),
                        fontBytes: try font.loadBytes(),
                        fontID: font.path,
                        fontName: font.name
                    ),
                    .init(
                        sourceRange: split..<Self.text.utf8.count,
                        font: .system(size: 36),
                        fontBytes: try secondFont.loadBytes(),
                        fontID: secondFont.path,
                        fontName: secondFont.name
                    )
                ],
                maximumLineWidth: Self.lineWidth,
                lineHeight: .multiple(1.35)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            breakLegend

            Canvas { context, _ in
                guard case .success(let information) = information else { return }
                for (lineIndex, line) in information.lines.enumerated() {
                    let contentFrame = rect(
                        for: line.typographicBounds,
                        lineIndex: lineIndex,
                        information: information
                    )
                    let lineFrame = rect(
                        for: line.lineBounds,
                        lineIndex: lineIndex,
                        information: information
                    )
                    let availableFrame = CGRect(
                        x: Self.origin.x,
                        y: lineFrame.minY,
                        width: CGFloat(line.maximumWidth),
                        height: lineFrame.height
                    )
                    context.stroke(
                        Path(availableFrame),
                        with: .color(.white.opacity(0.35)),
                        style: .init(lineWidth: 1, dash: [8, 5])
                    )
                    context.stroke(
                        Path(lineFrame),
                        with: .color(.yellow),
                        lineWidth: 2
                    )
                    context.stroke(
                        Path(contentFrame),
                        with: .color(.green),
                        style: .init(lineWidth: 1, dash: [4, 3])
                    )
                }
                for (index, glyph) in information.glyphs.enumerated() {
                    let color = Self.colors[glyph.runIndex % Self.colors.count]
                    context.stroke(
                        Path(rect(
                            for: glyph.typographicBounds,
                            lineIndex: glyph.lineIndex,
                            information: information
                        )),
                        with: .color(color.opacity(index == hoveredGlyph ? 1 : 0.55)),
                        style: .init(
                            lineWidth: index == hoveredGlyph ? 2 : 1,
                            dash: [5, 4]
                        )
                    )
                    if let renderBounds = glyph.renderBounds {
                        context.stroke(
                            Path(rect(
                                for: renderBounds,
                                lineIndex: glyph.lineIndex,
                                information: information
                            )),
                            with: .color(color.opacity(index == hoveredGlyph ? 1 : 0.55)),
                            lineWidth: index == hoveredGlyph ? 2 : 1
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    guard case .success(let information) = information else { return }
                    let nextHoveredGlyph = information.glyphs.indices.last {
                        let glyph = information.glyphs[$0]
                        return rect(
                            for: glyph.typographicBounds,
                            lineIndex: glyph.lineIndex,
                            information: information
                        ).contains(location)
                            || information.glyphs[$0].renderBounds.map {
                                rect(
                                    for: $0,
                                    lineIndex: glyph.lineIndex,
                                    information: information
                                ).contains(location)
                            } == true
                    }
                    guard hoveredGlyph != nextHoveredGlyph else { return }
                    hoveredGlyph = nextHoveredGlyph
                case .ended:
                    guard hoveredGlyph != nil else { return }
                    hoveredGlyph = nil
                }
            }
        }
        .padding(24)
        .sidebar(isPresented: $isShowing) {
            details
        }
    }

    @ViewBuilder
    private var breakLegend: some View {
        switch information {
        case .success(let information):
            breakText(information)
                .font(.title3)
                .lineSpacing(6)
                .frame(maxWidth: 760, alignment: .leading)
        case .failure(let error):
            ContentUnavailableView(
                "Run shaping failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
            .foregroundStyle(.red)
        }
    }

    private func breakText(_ information: Font.RunDebugInfo) -> Text {
        let bytes = Array(Self.text.utf8)
        var lowerBound = 0
        var result = Text("")
        for opportunity in information.breaks {
            let segment = String(
                decoding: bytes[lowerBound..<opportunity.sourceOffset],
                as: UTF8.self
            )
            let marker: String
            let color: Color
            switch opportunity.kind {
            case .allowed:
                marker = "│"
                color = .yellow
            case .softHyphen:
                marker = "‐"
                color = .orange
            case .mandatory:
                marker = "↵"
                color = .red
            }
            result = result + Text(segment) + Text(marker).foregroundColor(color)
            lowerBound = opportunity.sourceOffset
        }
        return result
    }

    @ViewBuilder
    private var details: some View {
        switch information {
        case .success(let information):
            if let hoveredGlyph {
                let glyph = information.glyphs[hoveredGlyph]
                let run = information.runs[glyph.runIndex]
                LabeledContent("Source", value: run.source)
                LabeledContent("Source UTF-8", value: description(run.sourceRange))
                LabeledContent("Glyph range", value: description(run.glyphRange))
                LabeledContent("Font", value: run.fontName)
                LabeledContent("Size", value: run.size.description)
                LabeledContent("Direction", value: run.direction.rawValue)
                LabeledContent("Script", value: run.script)
                LabeledContent("Glyph ID", value: glyph.glyphID.description)
                LabeledContent("Advance", value: glyph.advance.description)
            } else {
                ForEach(information.lines.indices, id: \.self) { index in
                    let line = information.lines[index]
                    Section("Line \(index + 1)") {
                        LabeledContent("Consumed source", value: description(line.consumedSourceRange))
                        LabeledContent("Consumed glyphs", value: description(line.consumedGlyphRange))
                        LabeledContent("Visible glyphs", value: description(line.visibleGlyphRange))
                        LabeledContent("Break", value: line.breakKind.rawValue)
                        LabeledContent("Advance", value: line.advance.description)
                        LabeledContent("Baseline offset", value: line.baselineOffset.description)
                        LabeledContent("Line height", value: line.lineBounds.height.description)
                    }
                }
            }
        case .failure(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.red)
        }
    }

    private func rect(
        for bounds: Font.GlyphDebugInfo.Bounds,
        lineIndex: Int,
        information: Font.RunDebugInfo
    ) -> CGRect {
        CGRect(
            x: Self.origin.x + CGFloat(bounds.x),
            y: baselineY(for: lineIndex, information: information) + CGFloat(bounds.y),
            width: CGFloat(bounds.width),
            height: CGFloat(bounds.height)
        )
    }

    private func baselineY(
        for lineIndex: Int,
        information: Font.RunDebugInfo
    ) -> CGFloat {
        var baseline = Self.origin.y
        guard lineIndex > 0 else { return baseline }
        for index in 1...lineIndex {
            let previous = information.lines[index - 1]
            let current = information.lines[index]
            baseline += CGFloat(
                previous.lineBounds.height - previous.baselineOffset
                    + current.baselineOffset
            )
        }
        return baseline
    }

    private func description(_ range: Range<Int>) -> String {
        "\(range.lowerBound)..<\(range.upperBound)"
    }
}
