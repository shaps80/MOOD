import PixlUI

struct Test: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstBaseline) {
                    Text("Hello, world!")
                    EmptyView()
                }

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstBaseline) {
                        Text("Hello, world!")
                        EmptyView()
                    }
                }
            }
            .content

            HStack(alignment: .firstBaseline) {
                Text("Hello, world!")
                EmptyView()
            }
        }
    }
}
