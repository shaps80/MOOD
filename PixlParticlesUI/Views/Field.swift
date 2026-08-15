import SwiftUI

struct Field: View {
    @State private var isDragging: Bool = false
    @State private var isShowingField: Bool = false
    @State private var currentValue: Double
    @FocusState private var focused

    @Binding var value: Double
    var step: Double?

    init(value: Binding<Double>, step: Double? = nil) {
        _value = value
        _currentValue = .init(initialValue: value.wrappedValue)
        self.step = step
    }

    var body: some View {
        Text(
            value,
            format: .number.precision(.fractionLength(0))
        )
        .foregroundStyle(.foreground)
        .opacity(isShowingField ? 0 : 1)
        .overlay {
            TextField(
                "",
                value: $currentValue,
                format: .number.precision(.fractionLength(0)).grouping(.never)
            )
            .focused($focused)
            .textFieldStyle(.plain)
            .focusEffectDisabled()
            .fixedSize()
            .opacity(isShowingField ? 1 : 0)
#if os(macOS)
            .offset(x: 3)
#endif
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(.quinary, in: .capsule)
        .overlay {
            Capsule()
                .stroke(.tint, lineWidth: 1.5)
                .opacity(isDragging || isShowingField ? 1 : 0)
                .animation(.snappy, value: isDragging)
                .animation(.snappy, value: isShowingField)
                .allowsHitTesting(false)
        }
        .onChange(of: focused) { _, newValue in
            isShowingField = newValue
        }
        .onChange(of: isShowingField) { _, _ in
            currentValue = value
        }
        .onKeyPress(.escape) {
            focused = false
            isShowingField = false
            return .handled
        }
        .onSubmit {
            focused = false
            isShowingField = false
            value = currentValue
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
                    isDragging = true
                    // LLM translate to increment, decrement by step ?? 1
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
    }
}


private extension LabeledContentStyle where Self == InspectorLabeledContentStyle {
    static var inspector: Self { .init() }
}

private struct InspectorLabeledContentStyle: LabeledContentStyle {
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

    ScrollView {
        VStack {
            Divided {
                LabeledContent("Duration") {
                    Field(value: $value)
                }
            }
        }
        .scenePadding()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }
    .labeledContentStyle(.inspector)
    .glassEffect(.clear, in: .rect(cornerRadius: 28))
    .frame(maxWidth: 250)
    .scenePadding()
}
