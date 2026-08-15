import SwiftUI
import PixlParticles

struct ParticleCanvas: View {
    let sample: Sample
    let camera: Camera

    var body: some View {
        Canvas { context, size in
            guard let symbol = context.resolveSymbol(id: "particle") else { return }
            guard let viewport = camera.viewport(for: size) else { return }

            for particle in sample.particles {
                let position = particle.interpolated(by: sample.interpolation)
                guard let screenPosition = viewport.project(position) else {
                    continue
                }

                context.draw(symbol, at: screenPosition)
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
    ParticleCanvas(
        sample: System().sample(at: .now),
        camera: Camera(
            position: [300, 250, 450],
            target: .zero,
            projection: .perspective
        )
    )
}
