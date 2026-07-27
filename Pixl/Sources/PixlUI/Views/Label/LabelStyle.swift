import Swift

public protocol LabelStyle {
    typealias Configuration = LabelStyleConfiguration
    associatedtype Body: View

    @ContentBuilder
    func makeBody(configuration: Configuration) -> Body
}

public struct LabelStyleConfiguration {
    public typealias Title = StyleContent
    public typealias Icon = StyleContent

    public let title: Title
    public let icon: Icon

    init<Title: View, Icon: View>(title: Title, icon: Icon) {
        self.title = .init(title)
        self.icon = .init(icon)
    }
}

public typealias AnyLabelStyle = AnyStyle<LabelStyleConfiguration>

extension AnyStyle where Configuration == LabelStyleConfiguration {
    public init<Style: LabelStyle>(_ style: Style) {
        self.init(style) { style, configuration in
            style.makeBody(configuration: configuration)
        }
    }

    public static var titleAndIcon: Self {
        .init(TitleAndIconLabelStyle())
    }

    public static var titleOnly: Self {
        .init(TitleOnlyLabelStyle())
    }

    public static var iconOnly: Self {
        .init(IconOnlyLabelStyle())
    }
}

extension EnvironmentValues {
    @Entry var labelStyle: AnyLabelStyle = .titleAndIcon
}

extension View {
    public func labelStyle<Style: LabelStyle>(_ style: Style) -> some View {
        environment(\.labelStyle, .init(style))
    }
}
