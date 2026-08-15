import SwiftUI
import PixlParticles

struct ContentView: View {
    @State private var isPaused: Bool = true
    @State private var system: System = .init()
    @State private var fraction: Double = 0
    @State private var isScrubbing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { _ in
                let now = ContinuousClock.now
                
                ParticleCanvas(
                    system: system,
                    now: now,
                    isScrubbing: isScrubbing,
                    isPaused: isPaused
                )
            }

            Divider()

            ParticleTimeline(
                fraction: $fraction,
                isScrubbing: $isScrubbing
            )
        }
        .toolbar {
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

#Preview {
    ContentView()
}
