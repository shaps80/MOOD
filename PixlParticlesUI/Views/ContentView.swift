import SwiftUI
import PixlParticles

struct ContentView: View {
    @State private var isPlaying: Bool = false
    @State private var fraction: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation) { _ in
                let now = ContinuousClock.now
                ParticleCanvas(now: now, isPlaying: isPlaying)
            }

            Divider()
            
            ParticleTimeline(
                isPlaying: $isPlaying,
                fraction: $fraction
            )
        }
    }
}

#Preview {
    ContentView()
}
