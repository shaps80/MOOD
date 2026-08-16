import PixlParticles
import PixlRenderer
import SwiftUI

struct ParticleViewport: View {
    let system: System
    let isPaused: Bool
    let isScrubbing: Bool
    let cameraPreset: CameraPreset
    @Binding var perspectiveRotationX: Double
    @Binding var perspectiveRotationY: Double
    @Binding var perspectiveRotationZ: Double
    @Binding var perspectiveRotationW: Double
    @Binding var cameraZoom: Double
    @Binding var cameraTargetX: Double
    @Binding var cameraTargetY: Double
    @Binding var cameraTargetZ: Double
    @Binding var fraction: Double
    let pointLOD: PointLOD
    let isGroundPlaneVisible: Bool
    let cullingBounds: CullingBounds
    let playbackResetID: UInt64
    let onPlaybackComplete: () -> Void

    var body: some View {
        ParticleMetalView(
            system: system,
            isPaused: isPaused || isScrubbing,
            cameraPreset: cameraPreset,
            rotation: [
                Float(perspectiveRotationX),
                Float(perspectiveRotationY),
                Float(perspectiveRotationZ),
                Float(perspectiveRotationW),
            ],
            zoom: Float(cameraZoom),
            target: [
                Float(cameraTargetX),
                Float(cameraTargetY),
                Float(cameraTargetZ),
            ],
            pointLOD: pointLOD,
            isGroundPlaneVisible: isGroundPlaneVisible,
            cullingBounds: cullingBounds,
            seekTime: isScrubbing ? system.duration * fraction : nil,
            resetID: playbackResetID,
            onCameraChange: persistCamera,
            onTimeChange: updateFraction
        )
    }

    private func persistCamera(
        _ rotation: SIMD4<Float>,
        _ zoom: Float,
        _ target: SIMD3<Float>
    ) {
        perspectiveRotationX = Double(rotation.x)
        perspectiveRotationY = Double(rotation.y)
        perspectiveRotationZ = Double(rotation.z)
        perspectiveRotationW = Double(rotation.w)
        cameraZoom = Double(zoom)
        cameraTargetX = Double(target.x)
        cameraTargetY = Double(target.y)
        cameraTargetZ = Double(target.z)
    }

    private func updateFraction(_ time: Duration) {
        guard !isScrubbing, system.duration > .zero else { return }
        let wasComplete = fraction >= 1
        fraction = time / system.duration
        if !wasComplete, time >= system.duration {
            onPlaybackComplete()
        }
    }
}
