import Swift

public protocol LabelStyle {
    typealias Configuration = LabelStyleConfiguration
    associatedtype Body: View

    @ContentBuilder
    func makeBody(configuration: Configuration) -> Body
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
