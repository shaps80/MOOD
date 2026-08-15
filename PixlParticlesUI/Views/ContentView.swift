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

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { _ in
                let now = ContinuousClock.now
                let sample = system.sample(
                    at: now,
                    isPaused: isPaused || isScrubbing
                )

                ParticleCanvas(sample: sample)
                    .onChange(of: sample.time) { _, time in
                        guard !isScrubbing, system.duration > .zero else {
                            return
                        }

                        fraction = time / system.duration
                    }
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
