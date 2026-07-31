import SwiftUI

struct ContentView: View {
    @State private var font: PlaygroundFont = .senilita
    @State private var fonts: [PlaygroundFont] = PlaygroundFont.initial
    @State private var selection: String = "runs"

    var body: some View {
        TabView(selection: $selection) {
            MeasurementView(font: font)
                .tabItem {
                    Label("Measurement", systemImage: "ruler")
                }
                .tag("measure")

            ShapingView(font: font)
                .tabItem {
                    Label("Shaping", systemImage: "textformat")
                }
                .tag("shaping")

            RunsView(font: $font, fonts: fonts)
                .tabItem {
                    Label("Runs", systemImage: "square.split.2x1")
                }
                .tag("runs")
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if selection != "runs" {
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
