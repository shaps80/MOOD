import SwiftUI
import PixlParticles

struct ContentView: View {
    @State private var isPaused: Bool = true
    @State private var system: System = .init()
    @State private var fraction: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { _ in
                let now = ContinuousClock.now
                
                ParticleCanvas(
                    system: system,
                    now: now,
                    isPaused: isPaused
                )
            }

            Divider()
            
            ParticleTimeline(
                isPaused: $isPaused,
                fraction: $fraction
            )
        }
    }
}

#Preview {
    ContentView()
}
