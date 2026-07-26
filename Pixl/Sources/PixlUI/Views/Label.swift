import Swift

public struct Label<Title: View, Icon: View>: View {
    let title: Title
    let icon: Icon

    public var body: some View {
        HStack {
            icon
            title
        }
    }
}

extension Label where Title == Text, Icon == Image {
    public init(_ title: some StringProtocol, image name: String) {
        self.title = .init(title)
        self.icon = .init(name)
    }
}

extension Label where Title == EmptyView, Icon == Image {
    public init(image name: String) {
        self.title = .init()
        self.icon = .init(name)
    }
}

extension Label where Title == Text, Icon == EmptyView {
    public init(_ title: some StringProtocol) {
        self.title = Text(title)
        self.icon = .init()
    }
}
