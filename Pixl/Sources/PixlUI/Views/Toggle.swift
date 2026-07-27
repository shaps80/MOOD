import Swift

public struct Toggle<Label: View>: View {
    let label: Label
    @Binding var isOn: Bool

    public var body: some View {
        Button {
            isOn.toggle()
        } label: {
            label
        }
    }
}

extension Toggle where Label == Text {
    nonisolated public init(_ title: some StringProtocol, isOn: Binding<Bool>) {
        self.label = .init(title)
        self._isOn = isOn
    }
}

extension Toggle where Label == PixlUI.Label<Text, Image> {
    nonisolated public init(_ title: some StringProtocol, image name: String, isOn: Binding<Bool>) {
        self.label = .init(title, image: name)
        self._isOn = isOn
    }
}

extension Toggle {
    nonisolated public init(isOn: Binding<Bool>, @ContentBuilder _ label: () -> Label) {
        self._isOn = isOn
        self.label = label()
    }
}
