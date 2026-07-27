import Swift

public protocol DisclosureGroupStyle {
    typealias Configuration = DisclosureGroupStyleConfiguration
    associatedtype Body: View

    @ContentBuilder
    func makeBody(configuration: Configuration) -> Body
}

public struct DisclosureGroupStyleConfiguration {
    public typealias Label = StyleContent
    public typealias Content = StyleContent

    public let label: Label
    public let content: Content
    @Binding public var isExpanded: Bool

    init<Label: View, Content: View>(label: Label, content: Content, isExpanded: Binding<Bool>) {
        self.label = .init(label)
        self.content = .init(content)
        self._isExpanded = isExpanded
    }
}

public typealias AnyDisclosureGroupStyle = AnyStyle<DisclosureGroupStyleConfiguration>

extension AnyStyle where Configuration == DisclosureGroupStyleConfiguration {
    public init<Style: DisclosureGroupStyle>(_ style: Style) {
        self.init(style) { style, configuration in
            style.makeBody(configuration: configuration)
        }
    }

    public static var automatic: Self {
        .init(AutomaticDisclosureGroupStyle())
    }
}

extension EnvironmentValues {
    @Entry var disclosureGroupStyle: AnyDisclosureGroupStyle = .automatic
}

extension View {
    public func disclosureGroupStyle<S: DisclosureGroupStyle>(_ style: S) -> some View {
        environment(\.disclosureGroupStyle, .init(style))
    }
}
