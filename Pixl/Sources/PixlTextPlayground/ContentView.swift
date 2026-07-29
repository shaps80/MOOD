import SwiftUI
import PixlText

typealias Font = PixlText.Font

struct ContentView: View {
    private static let origin = CGPoint(x: 40, y: 160)

    @State private var isShowing: Bool = true
    @State private var hoveredGlyph: Int?

    private let glyphs: Result<[Font.GlyphDebugInfo], Error>

    init() {
        glyphs = Result {
            var output: [Font.GlyphDebugInfo] = []
            try Font.system(size: 48).forEachGlyph(in: "Hello, world!") {
                output.append($0)
            }
            return output
        }
    }

    var body: some View {
        Canvas { context, size in
            guard case .success(let glyphs) = glyphs else { return }

            for (index, glyph) in glyphs.enumerated() {
                context.stroke(
                    Path(rect(for: glyph)),
                    with: .color(hoveredGlyph == index ? .yellow : .gray),
                    lineWidth: hoveredGlyph == index ? 2 : 1
                )
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                guard case .success(let glyphs) = glyphs else { return }
                hoveredGlyph = glyphs.indices.last {
                    rect(for: glyphs[$0]).contains(location)
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
                        LabeledContent("Advance", value: glyph.advance.description)
                        LabeledContent("X", value: glyph.bounds.x.description)
                        LabeledContent("Width", value: glyph.bounds.width.description)
                        LabeledContent("Height", value: glyph.bounds.height.description)
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

    private func rect(for glyph: Font.GlyphDebugInfo) -> CGRect {
        CGRect(
            x: Self.origin.x + CGFloat(glyph.bounds.x),
            y: Self.origin.y + CGFloat(glyph.bounds.y),
            width: CGFloat(glyph.bounds.width),
            height: CGFloat(glyph.bounds.height)
        )
    }
}
