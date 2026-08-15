import SwiftUI
import PixlParticles

struct ParticleCanvas: View {
    private let system: System = .init()

    let now: ContinuousClock.Instant
    let isPlaying: Bool

    var body: some View {
        Canvas { context, size in
            guard let symbol = context.resolveSymbol(id: "particle") else { return }
            let sample = system.sample(
                at: now,
                isPaused: !isPlaying
            )

            for particle in sample.particles {
                let position = particle.interpolated(by: sample.interpolation)
                // center just for testing
                let x: Double = size.width / 2 + .init(position.x)
                let y: Double = size.height / 2 + .init(position.y)

                context.draw(symbol, at: .init(x: x, y: y))
            }
        } symbols: {
            Rectangle()
                .frame(width: 2, height: 2)
                .foregroundStyle(.gray)
                .tag("particle")
        }
    }
}

#Preview {
    ParticleCanvas(now: .now, isPlaying: true)
}
