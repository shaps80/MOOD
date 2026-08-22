import SwiftUI

struct Field: View {
    private let pointsPerStep: Double = 10

    @State private var isDragging: Bool = false
    @State private var isShowingField: Bool = false
    @State private var currentValue: Double
    @State private var dragStartValue: Double?
    @State private var selection: TextSelection?
    @FocusState private var focused

    @Binding var value: Double
    var step: Double?
    var range: ClosedRange<Double>
    var displayScale: Double
    var fractionDigits: Int

    init(
        value: Binding<Double>,
        step: Double? = nil,
        range: ClosedRange<Double> = -.infinity ... .infinity,
        displayScale: Double = 1,
        fractionDigits: Int = 0
    ) {
        precondition(displayScale.isFinite && displayScale > 0)
        precondition(fractionDigits >= 0)
        _value = value
        _currentValue = .init(
            initialValue: value.wrappedValue * displayScale
        )
        self.step = step
        self.range = range.lowerBound * displayScale
            ... range.upperBound * displayScale
        self.displayScale = displayScale
        self.fractionDigits = fractionDigits
    }

    var body: some View {
        Text(
            currentValue,
            format: .number.precision(.fractionLength(0 ... fractionDigits))
        )
        .foregroundStyle(.foreground)
        .opacity(isShowingField ? 0 : 1)
        .overlay {
            TextField(
                "",
                value: $currentValue,
                format: .number
                    .precision(.fractionLength(0 ... fractionDigits))
                    .grouping(.never)
            )
            .focused($focused)
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .fixedSize()
            .padding(10)
            .opacity(isShowingField ? 1 : 0)
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(.quinary, in: .capsule)
        .overlay {
            Capsule()
                .stroke(.tint, lineWidth: 1.5)
                .opacity(isDragging || isShowingField ? 1 : 0)
                .animation(.smooth.speed(2), value: isDragging)
                .animation(.smooth.speed(2), value: isShowingField)
                .allowsHitTesting(false)
        }
        .onChange(of: value) { oldValue, newValue in
            currentValue = newValue
        }
        .onChange(of: focused) { _, newValue in
            isShowingField = newValue
        }
        .onChange(of: isShowingField) { _, _ in
            currentValue = value * displayScale
        }
        .onKeyPress(.escape) {
            focused = false
            isShowingField = false
            return .handled
        }
        .onSubmit {
            focused = false
            isShowingField = false
            currentValue = clamped(currentValue)
            value = currentValue / displayScale
        }
        .gesture(
            TapGesture()
                .onEnded {
                    isShowingField = true
                    focused = true
                }
        )
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { state in
                    let startValue = dragStartValue ?? value * displayScale

                    if dragStartValue == nil {
                        dragStartValue = startValue
                    }

                    isDragging = true
                    let increments = (
                        -Double(state.translation.height) / pointsPerStep
                    ).rounded(.towardZero)

                    currentValue = clamped(
                        startValue + increments * (step ?? 1)
                    )
                }
                .onEnded { _ in
                    isDragging = false
                    dragStartValue = nil
                    value = currentValue / displayScale
                }
        )
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}


extension LabeledContentStyle where Self == InspectorLabeledContentStyle {
    static var inspector: Self { .init() }
}

struct InspectorLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            configuration.content
        }
    }
}

#Preview {
    @Previewable @State var value: Double = 20

    LabeledContent("Duration") {
        Field(value: $value)
    }
    .scenePadding()
}
