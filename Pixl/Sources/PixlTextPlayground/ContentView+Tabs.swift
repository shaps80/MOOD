import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MeasurementView()
                .tabItem {
                    Label("Measurement", systemImage: "ruler")
                }

            ShapingView()
                .tabItem {
                    Label("Shaping", systemImage: "textformat")
                }
        }
    }
}
