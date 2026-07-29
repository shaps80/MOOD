import SwiftUI

@main
struct PixlTextPlayground: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isShowing: Bool = false

    var body: some View {
        Canvas { context, size in

        }
        .overlay(alignment: .trailing) {
            ZStack {
                if isShowing {
                    Form {
                        
                    }
                    .toolbarTitleDisplayMode(.inline)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: 300, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .scenePadding()
            .toolbar {
                Button("Toggle Panel", systemImage: "sidebar.right") {
                    withAnimation(.snappy) {
                        isShowing.toggle()
                    }
                }
            }
        }
    }
}
