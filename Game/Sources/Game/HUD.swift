import PixlUI

public struct Debug: View {
    private let bindings: PlayerBindings = .init()
    @State private var isExpanded: Bool = false

    private var chevron: String {
        isExpanded ? "▼" : "▶"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            DislosureGroup(
                "Hello, world!",
                image: isExpanded ? "checked" : "unchecked",
                isExpanded: $isExpanded
            ) {
                Label {
                    Text("Test")
                        .background {
                            Rectangle()
                        }
                } icon: {
                    Image("checked")
                        .renderingMode(.template)
                }
                .foregroundStyle(.orange)
                .padding(5)
            }
            .disclosureGroupStyle(.plain)
            .onInput(bindings.space) { _, _ in
                isExpanded.toggle()
            }
        }
        .padding(5)
        .sidebar()
    }
}

public struct PlainDisclosureGroupStyle: DisclosureGroupStyle {
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
    }
}

extension DisclosureGroupStyle where Self == PlainDisclosureGroupStyle {
    public static var plain: Self { .init() }
}


extension View {
    func highlight(_ color: Color = .white) -> some View {
        background {
            Rectangle()
                .foregroundStyle(color.opacity(0.5))
        }
    }
}
