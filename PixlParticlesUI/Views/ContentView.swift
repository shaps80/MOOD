import SwiftUI
import PixlParticles

struct ContentView: View {
    @State private var isPaused: Bool = true
    @State private var system: System = .init(duration: .seconds(10))
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
            .onChange(of: fraction) { _, fraction in
                guard isScrubbing else { return }

                system.seek(to: system.duration * fraction)
            }
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
