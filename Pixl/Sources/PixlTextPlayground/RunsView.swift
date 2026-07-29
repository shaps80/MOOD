import SwiftUI
import PixlText

struct RunsView: View {
    private static let text = "Hello, world!"
    private static let origin = CGPoint(x: 40, y: 170)
    private static let colors: [Color] = [.cyan, .orange]

    @State private var isShowing: Bool = true
    @State private var hoveredGlyph: Int?

    private let information: Result<Font.RunDebugInfo, Error>

    init(font: PlaygroundFont) {
        information = Result {
            let secondFont = font.path == PlaygroundFont.zapfino.path
                ? PlaygroundFont.senilita
                : PlaygroundFont.zapfino
            let split = "Hello, ".utf8.count
            return try Font.runDebugInfo(
                in: Self.text,
                runs: [
                    .init(
                        sourceRange: 0..<split,
                        font: .system(size: 48),
                        fontBytes: try font.loadBytes(),
                        fontID: font.path,
                        fontName: font.name
                    ),
                    .init(
                        sourceRange: split..<Self.text.utf8.count,
                        font: .system(size: 64),
                        fontBytes: try secondFont.loadBytes(),
                        fontID: secondFont.path,
                        fontName: secondFont.name
                    )
                ]
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sourceLegend

            Canvas { context, _ in
                guard case .success(let information) = information else { return }
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
    private var sourceLegend: some View {
        switch information {
        case .success(let information):
            HStack(spacing: 0) {
                ForEach(information.runs.indices, id: \.self) { index in
                    let run = information.runs[index]
                    Text(run.source)
                        .font(.title)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Self.colors[index % Self.colors.count].opacity(0.22))
                        .overlay {
                            Rectangle().stroke(Self.colors[index % Self.colors.count])
                        }
                }
            }
        case .failure(let error):
            ContentUnavailableView(
                "Run shaping failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
            .foregroundStyle(.red)
        }
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
                Text("Hover over a glyph bound")
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
