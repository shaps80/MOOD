import PixlUI

public struct HUD: View {
    @State private var isOn: Bool = false

    public var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("First")
                    .highlight(.green)

                Text("Second")
                    .highlight(.blue)
            }

            Toggle("", isOn: $isOn)
                .highlight(.red)
        }
        .padding(10)
        .background {
            Rectangle()
                .highlight(.black)
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
