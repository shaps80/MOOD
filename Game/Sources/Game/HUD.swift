import PixlUI

public struct HUD: View {
    public var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("First")
                    .highlight(.green)

                Text("Second")
                    .highlight(.blue)
            }
            .highlight(.tertiary)

            Text("Third")
                .highlight(.orange)
        }
        .padding(2)
        .highlight(.quaternary)
    }
}

extension View {
    func highlight(_ color: Color) -> some View {
        background {
            Rectangle()
                .stroke(color, lineWidth: 1)
        }
    }
}

