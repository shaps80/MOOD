import Swift

public struct Button<Label: View>: View {
    let label: Label
    let action: () -> Void

    public var body: some View {
        label
    }
}

extension Button where Label == PixlUI.Label<Text, Image> {
    nonisolated public init(_ title: some StringProtocol, image name: String, action: @escaping () -> Void) {
        self.label = .init(title, image: name)
        self.action = action
    }
}

extension Button where Label == Image {
    nonisolated public init(image name: String, action: @escaping () -> Void) {
        self.label = .init(name)
        self.action = action
    }
}

extension Button where Label == Text {
    nonisolated public init(_ title: some StringProtocol, action: @escaping () -> Void) {
        self.label = .init(title)
        self.action = action
    }
}

extension Button {
    nonisolated public init(_ action: @escaping () -> Void, @ContentBuilder label: () -> Label) {
        self.label = label()
        self.action = action
    }
}
