import Swift

public struct Button<Label: View>: View {
    let label: Label
    let action: () -> Void

    public var body: some View {
        label
    }
}

extension Button where Label == PixlUI.Label<Text, Image> {
    public init(_ title: some StringProtocol, image name: String, action: @escaping () -> Void) {
        self.label = .init(title, image: name)
        self.action = action
    }
}

extension Button where Label == Image {
    public init(image name: String, action: @escaping () -> Void) {
        self.label = .init(name)
        self.action = action
    }
}

extension Button where Label == Text {
    public init(_ title: some StringProtocol, action: @escaping () -> Void) {
        self.label = .init(title)
        self.action = action
    }
}

extension Button {
    public init(_ action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.label = label()
        self.action = action
    }
}
