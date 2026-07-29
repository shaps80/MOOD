import SwiftUI

struct ContentView: View {
    @State private var font: PlaygroundFont = .senilita
    @State private var fonts: [PlaygroundFont] = PlaygroundFont.initial

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

            RunsView(font: font)
                .tabItem {
                    Label("Runs", systemImage: "square.split.2x1")
                }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Font", selection: $font) {
                    ForEach(fonts) { font in
                        Text(font.name).tag(font)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(minWidth: 180)
            }
        }
        .task {
            let installed = await Task.detached(priority: .utility) {
                PlaygroundFont.installed()
            }.value
            guard !installed.isEmpty else { return }
            fonts = installed
            if !installed.contains(font) {
                font = installed[0]
            }
        }
    }
}
