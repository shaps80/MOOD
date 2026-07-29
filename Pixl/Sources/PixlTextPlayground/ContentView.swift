import SwiftUI
import PixlText

typealias Font = PixlText.Font

struct MeasurementView: View {
    private static let origin = CGPoint(x: 40, y: 160)

    @State private var isShowing: Bool = true
    @State private var hoveredGlyph: Int?

    private let glyphs: Result<[Font.GlyphDebugInfo], Error>

    init(font: PlaygroundFont) {
        glyphs = Result {
            var output: [Font.GlyphDebugInfo] = []
            let bytes = try font.loadBytes()
            try Font.system(size: 48).forEachGlyph(
                in: "He\u{301}llo, world!",
                fontBytes: bytes,
                fontID: font.path
            ) {
                output.append($0)
            }
            return output
        }
    }

    var body: some View {
        Canvas { context, size in
            guard case .success(let glyphs) = glyphs else { return }

            for (index, glyph) in glyphs.enumerated() where index != hoveredGlyph {
                context.stroke(
                    Path(typographicRect(for: glyph)),
                    with: .color(.gray),
                    style: .init(lineWidth: 1, dash: [5, 4])
                )
                if let renderRect = renderRect(for: glyph) {
                    context.stroke(
                        Path(renderRect),
                        with: .color(.gray),
                        lineWidth: 1
                    )
                }
            }

            for (index, glyph) in glyphs.enumerated() where hoveredGlyph == index {
                context.stroke(
                    Path(typographicRect(for: glyph)),
                    with: .color(.yellow),
                    style: .init(lineWidth: 1.5, dash: [5, 4])
                )
                if let renderRect = renderRect(for: glyph) {
                    context.stroke(
                        Path(renderRect),
                        with: .color(.red),
                        lineWidth: 1.5
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                guard case .success(let glyphs) = glyphs else { return }
                hoveredGlyph = glyphs.indices.last {
                    typographicRect(for: glyphs[$0]).contains(location)
                        || renderRect(for: glyphs[$0])?.contains(location) == true
                }

            case .ended:
                hoveredGlyph = nil
            }
        }
        .sidebar(isPresented: $isShowing) {
            Section {
                switch glyphs {
                case .success(let glyphs):
                    if let hoveredGlyph {
                        let glyph = glyphs[hoveredGlyph]
                        LabeledContent("Scalar", value: String(glyph.scalar))
                        LabeledContent("Glyph ID", value: glyph.glyphID.description)
                        LabeledContent("Source UTF-8", value: description(glyph.cluster.sourceRange))
                        LabeledContent("Glyph range", value: description(glyph.cluster.glyphRange))
                        LabeledContent("Advance", value: glyph.advance.description)
                        LabeledContent("Typographic", value: description(glyph.typographicBounds))
                        if let renderBounds = glyph.renderBounds {
                            LabeledContent("Render", value: description(renderBounds))
                        }
                    } else {
                        Text("Hover over a glyph bound")
                    }

                case .failure(let error):
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func typographicRect(for glyph: Font.GlyphDebugInfo) -> CGRect {
        rect(for: glyph.typographicBounds)
    }

    private func renderRect(for glyph: Font.GlyphDebugInfo) -> CGRect? {
        glyph.renderBounds.map(rect)
    }

    private func rect(for bounds: Font.GlyphDebugInfo.Bounds) -> CGRect {
        CGRect(
            x: Self.origin.x + CGFloat(bounds.x),
            y: Self.origin.y + CGFloat(bounds.y),
            width: CGFloat(bounds.width),
            height: CGFloat(bounds.height)
        )
    }

    private func description(_ bounds: Font.GlyphDebugInfo.Bounds) -> String {
        "x: \(bounds.x), y: \(bounds.y), w: \(bounds.width), h: \(bounds.height)"
    }

    private func description(_ range: Range<Int>) -> String {
        "\(range.lowerBound)..<\(range.upperBound)"
    }
}
