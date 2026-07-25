import PixlUI

public struct Test: View {
    public init() { }
    public var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstBaseline) {
                    Text("First")
                    EmptyView()
                }

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstBaseline) {
                        Text("Second")
                        EmptyView()
                    }
                }
            }

            HStack(alignment: .firstBaseline) {
                Text("Third")
                EmptyView()
                Rectangle()
                    .foregroundStyle(.secondary)
            }
        }
        .background {
            Text("Background")
            EmptyView()
        }
        .overlay {
            Text("Overlay")
            EmptyView()
        }
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
