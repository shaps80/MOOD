import SwiftUI

struct ContentView: View {
    @State private var font: PlaygroundFont = .senilita

    var body: some View {
        TabView {
            MeasurementView(font: font)
                .tabItem {
                    Label("Measurement", systemImage: "ruler")
                }

            ShapingView(font: font)
                .tabItem {
                    Label("Shaping", systemImage: "textformat")
                }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Font", selection: $font) {
                    ForEach(PlaygroundFont.allCases) { font in
                        Text(font.name).tag(font)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }
}
