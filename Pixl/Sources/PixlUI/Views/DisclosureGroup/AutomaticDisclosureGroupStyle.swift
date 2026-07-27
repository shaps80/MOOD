import Swift
import Pixl2D

public struct AutomaticDisclosureGroupStyle: DisclosureGroupStyle {
    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                configuration.label
            }

            if configuration.isExpanded {
                configuration.content
            }
        }
        .frame(maxWidth: .infinity)
        .background(.gray, in: .concentric)
    }
}

extension DisclosureGroupStyle where Self == AutomaticDisclosureGroupStyle {
    public static var automatic: Self { .init() }
}
