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

// origin: (350.0, 285.0), size: (100.0, 30.0)
let root = ViewGraph.build {
    Text("Hello")
        .padding(.all, 30)
}

print(
    root.layout(
        in: .init(width: 800, height: 600),
        displayScale: 1
    )
)
