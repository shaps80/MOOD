import PixlUI

public struct Debug: View {
    private let bindings: PlayerBindings = .init()
    @State private var isExpanded: Bool = false

    private var chevron: String {
        isExpanded ? "▼" : "▶"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
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
//            .labelStyle(.titleAndIcon)
//            .padding(2)
//            .highlight(.gray)
            
//            DislosureGroup(
//                "\(chevron) Hello, world!",
//                image: "unchecked",
//                isExpanded: $isExpanded
//            ) {
//                Text("This is some useful text")
//            }
//            .onInput(bindings.space) { _, _ in
//                isExpanded.toggle()
//            }
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
