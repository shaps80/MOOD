import SwiftUI
import PixlParticles

struct ParticleCanvas: View {
    private let groundPlane = GroundPlane(
        height: -110,
        extent: 500,
        spacing: 50
    )

    let sample: Sample
    let camera: Camera
    let groundPlaneStyle: GroundPlane.Style

    var body: some View {
        Canvas { context, size in
            guard let symbol = context.resolveSymbol(id: "particle") else { return }
            guard let viewport = camera.viewport(for: size) else { return }
            context.stroke(
                groundPlane.path(
                    in: viewport,
                    style: groundPlaneStyle
                ),
                with: .color(.gray.opacity(0.2)),
                lineWidth: 0.5
            )

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
        .background(.background.secondary)
    }
}

#Preview {
    ParticleCanvas(
        sample: System().sample(at: .now),
        camera: CameraPreset.perspective.fixedCamera,
        groundPlaneStyle: .grid
    )
}
