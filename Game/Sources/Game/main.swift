import PixlUI

extension View {
    func highlight(_ color: Color) -> some View {
        background {
            Rectangle()
                .stroke(color, lineWidth: 1)
        }
    }
}

public struct Test: View {
    public init() { }
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

let root = ViewGraph.build {
    VStack(alignment: .trailing) {
        Text("Hello world")
        Text("Hello")
    }
}

print(
    root.layout(
        in: .init(width: 800, height: 600),
        displayScale: 1
    )
)
