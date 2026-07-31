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
                let contentFrame = rect(for: information.line.typographicBounds)
                let lineFrame = rect(for: information.line.lineBounds)
                let availableFrame = CGRect(
                    x: Self.origin.x,
                    y: lineFrame.minY,
                    width: CGFloat(information.line.maximumWidth),
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
                for (index, glyph) in information.glyphs.enumerated() {
                    let color = Self.colors[glyph.runIndex % Self.colors.count]
                    context.stroke(
                        Path(rect(for: glyph.typographicBounds)),
                        with: .color(color.opacity(index == hoveredGlyph ? 1 : 0.55)),
                        style: .init(
                            lineWidth: index == hoveredGlyph ? 2 : 1,
                            dash: [5, 4]
                        )
                    )
                    if let renderBounds = glyph.renderBounds {
                        context.stroke(
                            Path(rect(for: renderBounds)),
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
                        rect(for: information.glyphs[$0].typographicBounds).contains(location)
                            || information.glyphs[$0].renderBounds.map {
                                rect(for: $0).contains(location)
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
                LabeledContent("Consumed source", value: description(information.line.consumedSourceRange))
                LabeledContent("Consumed glyphs", value: description(information.line.consumedGlyphRange))
                LabeledContent("Visible glyphs", value: description(information.line.visibleGlyphRange))
                LabeledContent("Break", value: information.line.breakKind.rawValue)
                LabeledContent("Available", value: information.line.maximumWidth.description)
                LabeledContent("Advance", value: information.line.advance.description)
                LabeledContent("Ascent", value: information.line.ascent.description)
                LabeledContent("Descent", value: information.line.descent.description)
                LabeledContent("Leading", value: information.line.leading.description)
                LabeledContent("Natural above", value: information.line.naturalAbove.description)
                LabeledContent("Natural below", value: information.line.naturalBelow.description)
                LabeledContent("Baseline offset", value: information.line.baselineOffset.description)
                LabeledContent("Line height", value: information.line.lineBounds.height.description)
            }
        case .failure(let error):
            Text(error.localizedDescription)
                .foregroundStyle(.red)
        }
    }

    private func rect(for bounds: Font.GlyphDebugInfo.Bounds) -> CGRect {
        CGRect(
            x: Self.origin.x + CGFloat(bounds.x),
            y: Self.origin.y + CGFloat(bounds.y),
            width: CGFloat(bounds.width),
            height: CGFloat(bounds.height)
        )
    }

    private func description(_ range: Range<Int>) -> String {
        "\(range.lowerBound)..<\(range.upperBound)"
    }
}
