import PixlUI

public struct Debug: View {
    private let bindings: PlayerBindings = .init()
    @State private var isExpanded: Bool = false

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 28)
                    .frame(width: 200, height: 100)
                    .foregroundStyle(.red)

                Capsule()
                    .frame(width: 80, height: 100)

                Circle()
                    .frame(height: 100)
            }
        } label: {
            Text("\(isExpanded ? "▼" : "▶") Title")
                .highlight(.green)
        }
        .onInput(bindings.space) { _, _ in
            isExpanded.toggle()
        }
        .padding(5)
        .sidebar()
    }
}

extension View {
    func highlight(_ color: Color = .white) -> some View {
        background {
            ConcentricRectangle(.concentric, isUniform: true)
                .foregroundStyle(color.opacity(0.5))
        }
    }
}
