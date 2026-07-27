import Swift

public struct Label<Title: View, Icon: View>: View {
    @Environment(\.labelStyle) private var style

    let title: Title
    let icon: Icon

    public var body: some View {
        style.makeBody(
            configuration: .init(
                title: title,
                icon: icon
            )
        )
    }
}

extension Label {
    nonisolated public init(
        @ContentBuilder title: () -> Title,
        @ContentBuilder icon: () -> Icon
    ) {
        self.title = title()
        self.icon = icon()
    }
}

extension Label where Title == Text, Icon == Image {
    nonisolated public init(_ title: some StringProtocol, image name: String) {
        self.title = .init(title)
        self.icon = .init(name)
    }

    nonisolated public init(
        _ title: some StringProtocol,
        @ViewBuilder icon: () -> Icon
    ) {
        self.title = .init(title)
        self.icon = icon()
    }
}

extension Label where Title == EmptyView, Icon == Image {
    nonisolated public init(image name: String) {
        self.title = .init()
        self.icon = .init(name)
    }
}

extension Label where Title == Text, Icon == EmptyView {
    nonisolated public init(_ title: some StringProtocol) {
        self.title = Text(title)
        self.icon = .init()
    }
}
