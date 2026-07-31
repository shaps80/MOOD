import Foundation
import PixlText
import SwiftUI

struct RunsView: View {
    private struct ParagraphConfiguration: Hashable {
        var fontSize: Float
        var variations: [String: Float]
        var style: ParagraphStyle
    }

    private struct FontResource {
        let bytes: [UInt8]
        let axes: [PixlText.Font.Axis]
    }

    private static let paragraphs = [
        "Hello, world! Line breaking finds every legal opportunity before layout chooses which words fit. Explicit newlines remain mandatory.",
        "A second paragraph has enough text to wrap independently. Its lines share paragraph geometry while retaining direct glyph ranges.",
        "The final paragraph makes paragraph spacing and first and last baselines easy to inspect without introducing any presentation rules."
    ]
    private static let text = paragraphs.joined(separator: "\n")
    private static let paragraphRanges: [Range<Int>] = {
        var offset = 0
        return paragraphs.indices.map { index in
            let upperBound = offset
                + paragraphs[index].utf8.count
                + (index + 1 < paragraphs.count ? 1 : 0)
            defer { offset = upperBound }
            return offset..<upperBound
        }
    }()
    private static let fontID = "/Library/Fonts/SF-Pro.ttf"
    private static let fontResource: Result<FontResource, Error> = Result {
        let bytes = Array(try Data(contentsOf: URL(filePath: fontID)))
        let axes = try PixlText.Font.variationAxes(fontBytes: bytes, fontID: fontID)
        return FontResource(bytes: bytes, axes: axes)
    }
    private static let origin = CGPoint(x: 40, y: 40)
    private static let lineWidth: Float = 520

    @State private var isShowingSidebar = true
    @State private var selectedParagraph = 0
    @State private var minimumLines: UInt = 0
    @State private var maximumLines: UInt = 0
    @State private var overflow = PixlText.Overflow.visible
    @State private var defaultLineMetrics = PixlText.DefaultLineMetrics.automatic
    @State private var configurations: [ParagraphConfiguration]
    @State private var session: PixlText.Font.LayoutDebugSession
    @State private var information: Result<PixlText.Font.LayoutDebugInfo, Error>

    init() {
        let configurations = [
            ParagraphConfiguration(
                fontSize: 24,
                variations: [:],
                style: .init(spacing: .init(lineSpacing: 8, paragraphAfter: 28))
            ),
            ParagraphConfiguration(
                fontSize: 20,
                variations: [:],
                style: .init(spacing: .init(lineSpacing: 8, paragraphAfter: 28))
            ),
            ParagraphConfiguration(
                fontSize: 22,
                variations: [:],
                style: .init(spacing: .init(lineSpacing: 8, paragraphAfter: 28))
            )
        ]
        let session = PixlText.Font.LayoutDebugSession()
        _configurations = State(initialValue: configurations)
        _session = State(initialValue: session)
        _information = State(initialValue: Self.makeInformation(
            configurations,
            minimumLines: 0,
            maximumLines: 0,
            overflow: .visible,
            defaultLineMetrics: .automatic,
            session: session
        ))
    }

    var body: some View {
        Canvas { context, _ in
            guard case .success(let information) = information else { return }
            context.stroke(
                Path(rect(for: information.bounds)),
                with: .color(.blue),
                style: .init(lineWidth: 2, dash: [10, 6])
            )
            for run in information.runs {
                context.stroke(
                    Path(rect(for: run.bounds)),
                    with: .color(.gray),
                    lineWidth: 1
                )
            }
            for (index, paragraph) in information.paragraphs.enumerated() {
                context.stroke(
                    Path(rect(for: paragraph.bounds)),
                    with: .color(index == selectedParagraph ? .purple : .purple.opacity(0.45)),
                    style: .init(
                        lineWidth: index == selectedParagraph ? 3 : 1.5,
                        dash: [8, 5]
                    )
                )
            }
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture().onEnded { event in
                guard case .success(let information) = information,
                      let paragraph = information.paragraphs.indices.last(where: {
                          rect(for: information.paragraphs[$0].bounds).contains(event.location)
                      })
                else { return }
                selectedParagraph = paragraph
            }
        )
        .padding(24)
        .sidebar(isPresented: $isShowingSidebar) {
            details
        }
        .onChange(of: configurations) { _, _ in refresh() }
        .onChange(of: minimumLines) { _, _ in refresh() }
        .onChange(of: maximumLines) { _, _ in refresh() }
        .onChange(of: overflow) { _, _ in refresh() }
        .onChange(of: defaultLineMetrics) { _, _ in refresh() }
    }

    @ViewBuilder
    private var details: some View {
        switch information {
        case .success:
            Section("Layout") {
                Stepper(
                    "Minimum lines: \(minimumLines)",
                    value: minimumLinesBinding,
                    in: 0...20
                )
                Stepper(
                    maximumLines == 0
                        ? "Maximum lines: Unlimited"
                        : "Maximum lines: \(maximumLines)",
                    value: maximumLinesBinding,
                    in: 0...20
                )
                Picker("Overflow", selection: $overflow) {
                    Text("Visible").tag(PixlText.Overflow.visible)
                    Text("Clip").tag(PixlText.Overflow.clip)
                    Text("Trailing ellipsis").tag(PixlText.Overflow.trailingEllipsis)
                }
                Picker("Default line metrics", selection: $defaultLineMetrics) {
                    Text("Automatic").tag(PixlText.DefaultLineMetrics.automatic)
                    Text("Inherited").tag(PixlText.DefaultLineMetrics.inherited)
                }
            }

            Section("Paragraph") {
                Picker("Selection", selection: $selectedParagraph) {
                    ForEach(configurations.indices, id: \.self) { index in
                        Text("Paragraph \(index + 1)").tag(index)
                    }
                }
                Stepper(
                    "Font size \(configurations[selectedParagraph].fontSize, format: .number)",
                    value: configurationBinding(\.fontSize),
                    in: 6...144,
                    step: 1
                )
            }

            if !variationAxes.isEmpty {
                Section("Variations") {
                    ForEach(variationAxes) { axis in
                        let value = configurations[selectedParagraph].variations[axis.tag]
                            ?? axis.defaultValue
                        VStack(alignment: .leading) {
                            LabeledContent(axis.tag, value: value.formatted())
                            Slider(value: variationBinding(axis), in: axis.minimum...axis.maximum)
                        }
                    }
                }
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
            }
        case .failure(let error):
            ContentUnavailableView(
                "Layout failed",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
            .foregroundStyle(.red)
        }
    }

    private var variationAxes: [PixlText.Font.Axis] {
        guard case .success(let resource) = Self.fontResource else { return [] }
        return resource.axes
    }

    private func variationBinding(_ axis: PixlText.Font.Axis) -> Binding<Float> {
        .init(
            get: { configurations[selectedParagraph].variations[axis.tag] ?? axis.defaultValue },
            set: { configurations[selectedParagraph].variations[axis.tag] = $0 }
        )
    }

    private var minimumLinesBinding: Binding<UInt> {
        .init(
            get: { minimumLines },
            set: { value in
                if maximumLines != 0, maximumLines < value { maximumLines = value }
                minimumLines = value
            }
        )
    }

    private var maximumLinesBinding: Binding<UInt> {
        .init(
            get: { maximumLines },
            set: { value in
                if value != 0, minimumLines > value { minimumLines = value }
                maximumLines = value
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

    private func refresh() {
        information = Self.makeInformation(
            configurations,
            minimumLines: minimumLines,
            maximumLines: maximumLines,
            overflow: overflow,
            defaultLineMetrics: defaultLineMetrics,
            session: session
        )
    }

    private static func makeInformation(
        _ configurations: [ParagraphConfiguration],
        minimumLines: UInt,
        maximumLines: UInt,
        overflow: PixlText.Overflow,
        defaultLineMetrics: PixlText.DefaultLineMetrics,
        session: PixlText.Font.LayoutDebugSession
    ) -> Result<PixlText.Font.LayoutDebugInfo, Error> {
        Result {
            let resource = try fontResource.get()
            let baseConfiguration = configurations[0]
            let baseFont = PixlText.Font.LayoutDebugInfo.FontInput(
                font: configuredFont(baseConfiguration),
                fontBytes: resource.bytes,
                fontID: fontID
            )
            let overrides = zip(paragraphRanges, configurations).compactMap {
                range, configuration -> PixlText.Font.LayoutDebugInfo.Input? in
                guard configuration.fontSize != baseConfiguration.fontSize
                    || configuration.variations != baseConfiguration.variations
                else { return nil }
                return .init(
                    sourceRange: range,
                    font: .init(
                        font: configuredFont(configuration),
                        fontBytes: resource.bytes,
                        fontID: fontID
                    )
                )
            }
            return try session.layout(
                text,
                font: baseFont,
                overrides: overrides,
                constraints: .init(
                    width: lineWidth,
                    lines: .init(minimum: minimumLines, maximum: maximumLines),
                    overflow: overflow,
                    defaultLineMetrics: defaultLineMetrics
                ),
                lineHeight: .multiple(1.35),
                paragraphStyles: configurations.map(\.style)
            )
        }
    }

    private static func configuredFont(_ configuration: ParagraphConfiguration) -> PixlText.Font {
        configuration.variations.reduce(PixlText.Font.system(size: configuration.fontSize)) {
            $0.variation($1.key, value: $1.value)
        }
    }

    private func rect(for bounds: PixlText.Font.LayoutDebugInfo.Bounds) -> CGRect {
        CGRect(
            x: Self.origin.x + CGFloat(bounds.x),
            y: Self.origin.y + CGFloat(bounds.y),
            width: CGFloat(bounds.width),
            height: CGFloat(bounds.height)
        )
    }
}
