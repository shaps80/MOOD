import Swift

public protocol DisclosureGroupStyle {
    typealias Configuration = DisclosureGroupStyleConfiguration
    associatedtype Body : View
    @ContentBuilder func makeBody(configuration: Configuration) -> Body
}

public struct DisclosureGroupStyleConfiguration {
    public struct Label: View {
        public var body: some View {

        }
    }

    public struct Content: View {
        public var body: some View {

        }
    }

    let label: Label
    let content: Content
    @Binding var isExpanded: Bool
}

public protocol DislosureStyle {
    associatedtype Body: View
    @ContentBuilder func makeBody(configuration: Configuration) -> Body
    typealias Configuration = DisclosureGroupStyleConfiguration
}

internal extension DisclosureGroupStyle {
    func resolve(configuration: Configuration) -> some View {
        ResolvedDislosureStyle(configuration: configuration, style: self)
    }
}

private struct ResolvedDislosureStyle<Style: DisclosureGroupStyle>: View {
    var configuration: DisclosureGroupStyleConfiguration

    var style: Style

    var body: some View {
        style.makeBody(configuration: configuration)
    }
}

//internal extension EnvironmentValues {
//    @Entry var dislosureGroupStyle: (any DislosureGroupStyle)?
//}
//
public extension View {
    func dislosureGroupStyle(_ style: some DisclosureGroupStyle) -> some View {
//        environment(\.<#style#>Style, style)
        EmptyView()
    }
}

extension DisclosureGroupStyle where Self == AutomaticDisclosureGroupStyle {
    static var `default`: Self { .init() }
}

public struct AutomaticDisclosureGroupStyle: DisclosureGroupStyle {
    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                configuration.label
                    .padding(5)
            }

            if configuration.isExpanded {
                configuration.content
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .foregroundStyle(.background.opacity(0.2))
        }
    }
}
