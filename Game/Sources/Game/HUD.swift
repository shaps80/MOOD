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
                Image(isOn ? "checked" : "unchecked")
            }
            .onInput(bindings.space) { input, _ in
                isOn.toggle()
            }
        }
    }
}

extension View {
    func highlight(_ color: Color) -> some View {
        background {
            Rectangle()
                .stroke(color, lineWidth: 1)
                .foregroundStyle(color.opacity(0.3))
        }
    }
}
