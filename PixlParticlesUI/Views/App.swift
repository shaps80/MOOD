import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
            .preferredColorScheme(.dark)
        }
#if os(macOS)
        .defaultSize(width: 1280, height: 720)
        .defaultPosition(.center)
#endif
    }
}
