import PixlParticles
import PixlRenderer
import SwiftUI

struct ParticleViewport: View {
    let system: System
    let isPaused: Bool
    let isScrubbing: Bool
    let cameraPreset: CameraPreset
    @Binding var perspectiveYaw: Double
    @Binding var perspectivePitch: Double
    @Binding var cameraZoom: Double
    @Binding var fraction: Double
    let pointLOD: PointLOD

    var body: some View {
        ParticleMetalView(
            system: system,
            isPaused: isPaused || isScrubbing,
            cameraPreset: cameraPreset,
            yaw: Float(perspectiveYaw),
            pitch: Float(perspectivePitch),
            zoom: Float(cameraZoom),
            pointLOD: pointLOD,
            seekTime: isScrubbing ? system.duration * fraction : nil,
            onCameraChange: persistCamera,
            onTimeChange: updateFraction
        )
    }

    private func persistCamera(_ yaw: Float, _ pitch: Float, _ zoom: Float) {
        perspectiveYaw = Double(yaw)
        perspectivePitch = Double(pitch)
        cameraZoom = Double(zoom)
    }

    private func updateFraction(_ time: Duration) {
        guard !isScrubbing, system.duration > .zero else { return }
        fraction = time / system.duration
    }
}
