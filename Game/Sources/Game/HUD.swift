import PixlUI

public struct HUD: View {
    public var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("First")
                    .highlight(.green)

                Text("Second")
                    .highlight(.blue)
            }

            Text("Third")
                .highlight(.orange)
        }
        .padding(4)
        .background {
            Rectangle()
                .foregroundStyle(.red.opacity(0.3))
        }
    }
}

extension View {
    func highlight(_ color: Color) -> some View {
        background {
            Rectangle()
                .stroke(color, lineWidth: 2)
//                .foregroundStyle(color.opacity(0.2))
        }
    }
}
