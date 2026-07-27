import PixlUI

public struct Debug: View {
    private let bindings: PlayerBindings = .init()
    @State private var isExpanded: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            VStack(spacing: 28) {
                Rectangle()
                    .frame(width: 200, height: 200)
                    .foregroundStyle(.red)

                RoundedRectangle(cornerRadius: 28)
                    .frame(width: 200, height: 200)
                    .foregroundStyle(.red)
            }
            .padding()
//            DisclosureGroup(isExpanded: $isExpanded) {
//                Label {
//                    Text("Test")
//                        .background {
//                            Rectangle()
//                        }
//                } icon: {
//                    Image("checked")
//                }
//                .renderingMode(.template)
//                .foregroundStyle(.orange)
//                .padding(5)
//            } label: {
//                Label {
//                    Text("Hello, world!")
//                } icon: {
//                    ZStack {
//                        Image("unchecked").hidden()
//                        Text(isExpanded ? "▼" : "▶")
//                            .highlight(.green)
//                    }
//                }
//            }
//            .background(isExpanded ? .red : .gray, in: .rect)
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
