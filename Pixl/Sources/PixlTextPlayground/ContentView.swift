import SwiftUI

struct ContentView: View {
    @State private var isShowing: Bool = true

    var body: some View {
        Canvas { context, size in

        }
        .sidebar(isPresented: $isShowing) {
            Section {
                // todo
            }
        }
    }
}
