import Swift

public struct DislosureGroup<Label: View, Content: View>: View {
    @Binding private var isExpanded: Bool
    let style: any DisclosureGroupStyle = AutomaticDisclosureGroupStyle()

    let label: Label
    let content: Content

    public var body: some View {
//        style.resolve(configuration: .init(
//            label: .init(),
//            content: .init(),
//            isExpanded: $isExpanded
//        ))

        VStack(alignment: .leading) {
            Button {
                isExpanded.toggle()
            } label: {
                label
                    .padding(5)
            }

            if isExpanded {
                content
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .foregroundStyle(.background.opacity(0.2))
        }
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
