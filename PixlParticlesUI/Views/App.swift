import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
            }
        }
#if os(macOS)
        .defaultSize(width: 1920, height: 1080)
        .defaultPosition(.center)
#endif
    }
}
