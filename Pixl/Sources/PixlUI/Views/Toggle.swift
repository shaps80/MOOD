import Swift

public struct Toggle<Label: View>: View {
    let label: Label
    @Binding var isOn: Bool

    public var body: some View {
        label
    }
}

extension Toggle where Label == Text {
    public init(_ title: some StringProtocol, isOn: Binding<Bool>) {
        self.label = Text(title)
        self._isOn = isOn
    }
}

extension Toggle {
    public init(isOn: Binding<Bool>, @ViewBuilder _ label: () -> Label) {
        self._isOn = isOn
        self.label = label()
    }
}
