import SwiftUI
import PixlParticles

struct ContentView: View {
    private let durationInTicks: UInt64 = 60

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
            .onChange(of: fraction) { _, fraction in
                guard isScrubbing else { return }

                let tick = UInt64(
                    (fraction * Double(durationInTicks)).rounded()
                )
                system.seek(to: tick)
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
