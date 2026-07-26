import PixlUI
import Foundation

public struct HUD: View {
    @State private var isOn: Bool = true

    public var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("First")
                    .highlight(.green)

                Text("Second")
                    .highlight(.blue)
            }

            Toggle(isOn ? "ON" : "OFF", isOn: $isOn)
                .highlight(isOn ? .orange : .gray)
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
