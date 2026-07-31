import SwiftUI
import PixlText

struct RunsView: View {
    private static let text = """
    Hello, world! Line breaking finds every legal opportunity before layout chooses which words fit. Explicit newlines remain mandatory.
    A second paragraph gives us enough text to exercise wrapping across several future lines.
    """
    private static let origin = CGPoint(x: 40, y: 170)
    private static let lineWidth: Float = 520

    @State private var isShowing: Bool = true
    @State private var hoveredWord: Int?

    private let information: Result<Font.RunDebugInfo, Error>

    init(font: PlaygroundFont) {
        information = Result {
            let secondFont = font.path == PlaygroundFont.zapfino.path
                ? PlaygroundFont.senilita
                : PlaygroundFont.zapfino
            let primarySize: Float = font.path == PlaygroundFont.zapfino.path ? 18 : 32
            let secondarySize: Float = secondFont.path == PlaygroundFont.zapfino.path ? 18 : 32
            let split = "Hello, world! Line breaking finds every legal opportunity ".utf8.count
            return try Font.runDebugInfo(
                in: Self.text,
                runs: [
                    .init(
                        sourceRange: 0..<split,
                        font: .system(size: primarySize),
                        fontBytes: try font.loadBytes(),
                        fontID: font.path,
                        fontName: font.name
                    ),
                    .init(
                        sourceRange: split..<Self.text.utf8.count,
                        font: .system(size: secondarySize),
                        fontBytes: try secondFont.loadBytes(),
                        fontID: secondFont.path,
                        fontName: secondFont.name
                    )
                ],
                maximumLineWidth: Self.lineWidth,
                lineHeight: .multiple(1.35),
                lineSpacing: 8
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
                for (index, word) in information.words.enumerated() {
                    context.stroke(
                        Path(rect(
                            for: word.bounds,
                            lineIndex: word.lineIndex,
                            information: information
                        )),
                        with: .color(index == hoveredWord ? .yellow : .gray),
                        style: .init(
                            lineWidth: index == hoveredWord ? 2 : 1,
                            dash: [5, 4]
                        )
                    )
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    guard case .success(let information) = information else { return }
                    let nextHoveredWord = information.words.indices.last {
                        let word = information.words[$0]
                        return rect(
                            for: word.bounds,
                            lineIndex: word.lineIndex,
                            information: information
                        ).contains(location)
                    }
                    guard hoveredWord != nextHoveredWord else { return }
                    hoveredWord = nextHoveredWord
                case .ended:
                    guard hoveredWord != nil else { return }
                    hoveredWord = nil
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
            if let hoveredWord {
                let word = information.words[hoveredWord]
                LabeledContent("Word", value: word.source)
                LabeledContent("Line", value: (word.lineIndex + 1).description)
                LabeledContent("Source UTF-8", value: description(word.sourceRange))
                LabeledContent("Width", value: word.bounds.width.description)
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
            y: Self.origin.y
                + CGFloat(information.lines[lineIndex].baselineY)
                + CGFloat(bounds.y),
            width: CGFloat(bounds.width),
            height: CGFloat(bounds.height)
        )
    }

    private func description(_ range: Range<Int>) -> String {
        "\(range.lowerBound)..<\(range.upperBound)"
    }
}
