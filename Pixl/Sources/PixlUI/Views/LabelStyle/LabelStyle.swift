import Swift

public protocol LabelStyle {
    typealias Configuration = LabelStyleConfiguration
    associatedtype Body: View

    @ContentBuilder
    func makeBody(configuration: Configuration) -> Body
}

extension AnyStyle where Configuration == LabelStyleConfiguration {
    public init<Style: LabelStyle>(_ style: Style) {
        self.init(style) { style, configuration in
            style.makeBody(configuration: configuration)
        }
    }
}
