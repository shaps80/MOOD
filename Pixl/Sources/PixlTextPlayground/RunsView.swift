import SwiftUI
import PixlText

struct RunsView: View {
    private struct ParagraphConfiguration: Hashable {
        var font: PlaygroundFont
        var fontSize: Float
        var style: ParagraphStyle
    }

    private static let paragraphTexts = [
        "Hello, world! Line breaking finds every legal opportunity before layout chooses which words fit. Explicit newlines remain mandatory.",
        "A second paragraph has enough text to wrap independently. Its lines share paragraph geometry while retaining direct glyph ranges.",
        "The final paragraph makes paragraph spacing and first and last baselines easy to inspect without introducing any presentation rules."
    ]
    private static let text = paragraphTexts.joined(separator: "\n")
    private static let paragraphRanges: [Range<Int>] = {
        var offset = 0
        return paragraphTexts.indices.map { index in
            let upperBound = offset
                + paragraphTexts[index].utf8.count
                + (index + 1 < paragraphTexts.count ? 1 : 0)
            defer { offset = upperBound }
            return offset..<upperBound
        }
    }()
    private static let origin = CGPoint(x: 40, y: 170)
    private static let lineWidth: Float = 520

    @Binding private var font: PlaygroundFont
    private let fonts: [PlaygroundFont]
    @State private var isShowing: Bool = true
    @State private var hoveredWord: Int?
    @State private var hoveredParagraph: Int?
    @State private var selectedParagraph = 0
    @State private var configurations: [ParagraphConfiguration]
    @State private var information: Result<Font.RunDebugInfo, Error>

    init(font: Binding<PlaygroundFont>, fonts: [PlaygroundFont]) {
        _font = font
        self.fonts = fonts
        let primary = font.wrappedValue
        let secondary = primary.path == PlaygroundFont.zapfino.path
            ? PlaygroundFont.senilita
            : PlaygroundFont.zapfino
        let configurations = [primary, secondary, primary].map { font in
            ParagraphConfiguration(
                font: font,
                fontSize: font.path == PlaygroundFont.zapfino.path ? 12 : 24,
                style: .init(spacing: .init(lineSpacing: 8, paragraphAfter: 28))
            )
        }
        _configurations = State(initialValue: configurations)
        _information = State(initialValue: Self.makeInformation(configurations))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            breakLegend

            Canvas { context, _ in
                guard case .success(let information) = information else { return }
                for (index, paragraph) in information.paragraphs.enumerated() {
                    let isSelected = index == selectedParagraph
                    let isHovered = index == hoveredParagraph
                    context.stroke(
                        Path(rect(for: paragraph.bounds)),
                        with: .color(
                            isSelected
                                ? .purple
                                : (isHovered ? .purple.opacity(0.8) : .purple.opacity(0.4))
                        ),
                        style: .init(
                            lineWidth: isSelected ? 3 : (isHovered ? 2.5 : 1.5),
                            dash: [10, 5]
                        )
                    )
                }
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
                        x: Self.origin.x + CGFloat(line.availableX),
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
                    let nextHoveredParagraph = information.paragraphs.indices.last {
                        rect(for: information.paragraphs[$0].bounds).contains(location)
                    }
                    guard hoveredWord != nextHoveredWord
                            || hoveredParagraph != nextHoveredParagraph
                    else { return }
                    hoveredWord = nextHoveredWord
                    hoveredParagraph = nextHoveredParagraph
                case .ended:
                    guard hoveredWord != nil || hoveredParagraph != nil else { return }
                    hoveredWord = nil
                    hoveredParagraph = nil
                }
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        guard case .success(let information) = information else { return }
                        guard let paragraph = information.paragraphs.indices.last(where: {
                            rect(for: information.paragraphs[$0].bounds).contains(event.location)
                        }) else { return }
                        selectedParagraph = paragraph
                    }
            )
        }
        .padding(24)
        .sidebar(isPresented: $isShowing) {
            details
        }
        .onChange(of: configurations) { _, configurations in
            information = Self.makeInformation(configurations)
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
            Section("Paragraph") {
                Picker("Selection", selection: $selectedParagraph) {
                    ForEach(information.paragraphs.indices, id: \.self) { index in
                        Text("Paragraph \(index + 1)").tag(index)
                    }
                }

                Picker("Font", selection: fontBinding) {
                    ForEach(fonts) { font in
                        Text(font.name).tag(font)
                    }
                }

                Stepper(
                    "Font size \(configurations[selectedParagraph].fontSize, format: .number)",
                    value: configurationBinding(\.fontSize),
                    in: 6...144,
                    step: 1
                )
            }

            Section("Alignment") {
                Picker("Alignment", selection: configurationBinding(\.style.alignment)) {
                    ForEach(PixlText.TextAlignment.allCases, id: \.self) { alignment in
                        Text(alignmentLabel(alignment)).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section("Indentation") {
                valueStepper("Leading", keyPath: \.style.indentation.leading)
                valueStepper("Trailing", keyPath: \.style.indentation.trailing)
                valueStepper("First line", keyPath: \.style.indentation.firstLine)
            }

            Section("Spacing") {
                valueStepper("Line", keyPath: \.style.spacing.lineSpacing)
                valueStepper("Before", keyPath: \.style.spacing.paragraphBefore)
                valueStepper("After", keyPath: \.style.spacing.paragraphAfter)
            }

            Section("Hyphenation") {
                Picker("Mode", selection: configurationBinding(\.style.hyphenation)) {
                    Text("None").tag(PixlText.Hyphenation.none)
                    Text("Automatic").tag(PixlText.Hyphenation.automatic)
                }
                Text("Automatic insertion is not implemented yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let hoveredWord {
                let word = information.words[hoveredWord]
                Section("Hover") {
                    LabeledContent("Word", value: word.source)
                    LabeledContent("Line", value: (word.lineIndex + 1).description)
                    LabeledContent("Source UTF-8", value: description(word.sourceRange))
                    LabeledContent("Width", value: word.bounds.width.description)
                }
            }

            let paragraph = information.paragraphs[selectedParagraph]
            Section("Geometry") {
                Text(paragraph.source)
                LabeledContent("Source UTF-8", value: description(paragraph.sourceRange))
                LabeledContent("Lines", value: description(paragraph.lineRange))
                LabeledContent("First baseline", value: paragraph.firstBaselineY.description)
                LabeledContent("Last baseline", value: paragraph.lastBaselineY.description)
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

    private var fontBinding: Binding<PlaygroundFont> {
        .init(
            get: { configurations[selectedParagraph].font },
            set: { value in
                configurations[selectedParagraph].font = value
                font = value
            }
        )
    }

    private func configurationBinding<Value>(
        _ keyPath: WritableKeyPath<ParagraphConfiguration, Value>
    ) -> Binding<Value> {
        .init(
            get: { configurations[selectedParagraph][keyPath: keyPath] },
            set: { configurations[selectedParagraph][keyPath: keyPath] = $0 }
        )
    }

    private func valueStepper(
        _ label: String,
        keyPath: WritableKeyPath<ParagraphConfiguration, Float>
    ) -> some View {
        Stepper(
            "\(label) \(configurations[selectedParagraph][keyPath: keyPath], format: .number)",
            value: configurationBinding(keyPath),
            in: 0...160,
            step: 1
        )
    }

    private func alignmentLabel(_ alignment: PixlText.TextAlignment) -> String {
        switch alignment {
        case .leading: "Leading"
        case .center: "Center"
        case .trailing: "Trailing"
        }
    }

    private static func makeInformation(
        _ configurations: [ParagraphConfiguration]
    ) -> Result<Font.RunDebugInfo, Error> {
        Result {
            let runs = try zip(paragraphRanges, configurations).map { range, configuration in
                Font.RunDebugInfo.Input(
                    sourceRange: range,
                    font: .system(size: configuration.fontSize),
                    fontBytes: try configuration.font.loadBytes(),
                    fontID: configuration.font.path,
                    fontName: configuration.font.name
                )
            }
            return try Font.runDebugInfo(
                in: text,
                runs: runs,
                maximumLineWidth: lineWidth,
                lineHeight: .multiple(1.35),
                paragraphStyles: configurations.map(\.style)
            )
        }
    }
}
