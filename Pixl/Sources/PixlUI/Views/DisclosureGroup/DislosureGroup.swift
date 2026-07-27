import Swift

public struct DislosureGroup<Label: View, Content: View>: View {
    @Environment(\.disclosureGroupStyle) private var style
    @Binding private var isExpanded: Bool
    
    let label: Label
    let content: Content

    public var body: some View {
        style.makeBody(
            configuration: .init(
                label: label,
                content: content,
                isExpanded: $isExpanded
            )
        )
    }
}

extension DislosureGroup {
    public init(
        isExpanded: Binding<Bool>,
        @ContentBuilder content: () -> Content,
        @ContentBuilder label: () -> Label
    ) {
        _isExpanded = isExpanded
        self.content = content()
        self.label = label()
    }

    public init(
        @ContentBuilder content: () -> Content,
        @ContentBuilder label: () -> Label
    ) {
        _isExpanded = .constant(true)
        self.content = content()
        self.label = label()
    }
}

extension DislosureGroup where Label == Text {
    public init(
        _ title: some StringProtocol,
        isExpanded: Binding<Bool>,
        @ContentBuilder content: () -> Content
    ) {
        _isExpanded = isExpanded
        self.label = .init(title)
        self.content = content()
    }

    public init(
        _ title: some StringProtocol,
        @ContentBuilder content: () -> Content
    ) {
        _isExpanded = .constant(true)
        self.label = .init(title)
        self.content = content()
    }
}

extension DislosureGroup where Label == PixlUI.Label<Text, Image> {
    public init(
        _ title: some StringProtocol,
        image name: String,
        isExpanded: Binding<Bool>,
        @ContentBuilder content: () -> Content
    ) {
        _isExpanded = isExpanded
        self.label = .init(title, image: name)
        self.content = content()
    }

    public init(
        _ title: some StringProtocol,
        image name: String,
        @ContentBuilder content: () -> Content
    ) {
        _isExpanded = .constant(true)
        self.label = .init(title, image: name)
        self.content = content()
    }
}
