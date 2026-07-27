import Swift
import Pixl2D

public struct AutomaticDisclosureGroupStyle: DisclosureGroupStyle {
    public init() { }

    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                configuration.label
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if configuration.isExpanded {
                Divider()

                configuration.content
                    .padding(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.gray6.opacity(0.5), in: .concentric)
    }
}

extension DisclosureGroupStyle where Self == AutomaticDisclosureGroupStyle {
    public static var automatic: Self { .init() }
}
