import PixlUI
import Foundation

public struct HUD: View {
    let bindings: PlayerBindings = .init()
    @State private var isOn: Bool = true

    public var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("First")
                    .highlight(.green)

                Text("Second")
                    .highlight(.blue)
            }

            Toggle(isOn: $isOn) {
                Image("checked")
            }
            .onInput(bindings.space) { input, _ in
                isOn.toggle()
            }
//            .highlight(isOn ? .orange : .gray)
        }
    }
}

extension View {
    func highlight(_ color: Color) -> some View {
        background {
            Rectangle()
                .stroke(color, lineWidth: 2)
                .foregroundStyle(color.opacity(0.3))
        }
    }
}
