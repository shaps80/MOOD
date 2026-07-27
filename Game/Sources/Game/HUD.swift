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
                "\(chevron) Hello, world!",
                isExpanded: $isExpanded
            ) {
                Text("This is some useful text")
            }
            .onInput(bindings.space) { _, _ in
                isExpanded.toggle()
            }
        }
        .padding(5)
        .sidebar()
    }
}

extension View {
    func highlight(_ color: Color = .white) -> some View {
        background {
            Rectangle()
                .foregroundStyle(color.opacity(0.5))
        }
    }
}
