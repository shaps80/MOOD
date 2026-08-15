import SwiftUI
import PixlParticles

struct ContentView: View {
    private let system: System = .init(
        particleCount: 1_000,
        duration: .seconds(20)
    )

    @State private var isPaused: Bool = false
    @State private var fraction: Double = 0
    @State private var isScrubbing: Bool = false
    @State private var camera = Camera.perspective

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { _ in
                let now = ContinuousClock.now
                let sample = system.sample(
                    at: now,
                    isPaused: isPaused || isScrubbing
                )

                ParticleCanvas(
                    sample: sample,
                    camera: camera
                )
                .onChange(of: sample.time) { _, time in
                    guard !isScrubbing, system.duration > .zero else {
                        return
                    }

                    fraction = time / system.duration
                }
            }
        }
        .overlay(alignment: .bottom) {
            ParticleTimeline(
                fraction: $fraction,
                isScrubbing: $isScrubbing
            )
            .frame(maxWidth: 500)
            .onChange(of: fraction) { _, fraction in
                guard isScrubbing else { return }

                system.seek(to: system.duration * fraction)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Camera", selection: $camera) {
                    Text("Perspective").tag(Camera.perspective)
                    Text("Isometric").tag(Camera.isometric)
                }
                .pickerStyle(.segmented)
            }

            ToolbarItem {
                Button(
                    isPaused ? "Play" : "Pause",
                    systemImage: isPaused ? "play" : "pause"
                ) {
                    isPaused.toggle()
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }
}

#Preview {
    ContentView()
}
