import PixlParticles
import PixlRenderer
import SwiftUI

struct ParticleViewport: View {
    let system: System
    let isPaused: Bool
    let isScrubbing: Bool
    let duration: Duration
    @Binding var camera: EditorSettings.Camera
    @Binding var observerCamera: EditorSettings.Camera?
    @Binding var fraction: Double
    let pointLOD: PointLOD
    let isGroundPlaneVisible: Bool
    let isFrustumVisible: Bool
    let cullingBounds: CullingBounds
    let playbackResetID: UInt64
    let onPlaybackComplete: () -> Void

    var body: some View {
        ParticleMetalView(
            system: system,
            isPaused: isPaused || isScrubbing,
            duration: duration,
            cameraPreset: camera.preset,
            rotation: [
                Float(camera.rotationX),
                Float(camera.rotationY),
                Float(camera.rotationZ),
                Float(camera.rotationW),
            ],
            zoom: Float(camera.zoom),
            target: [
                Float(camera.targetX),
                Float(camera.targetY),
                Float(camera.targetZ),
            ],
            observerCamera: observerCamera,
            pointLOD: pointLOD,
            isGroundPlaneVisible: isGroundPlaneVisible,
            isFrustumVisible: isFrustumVisible && camera.preset == .perspective,
            cullingBounds: cullingBounds,
            seekTime: isScrubbing ? scrubDuration * fraction : nil,
            resetID: playbackResetID,
            onCameraChange: persistCamera,
            onTimeChange: updateFraction
        )
    }

    private var scrubDuration: Duration {
        duration == .zero ? .seconds(30) : duration
    }

    private func persistCamera(
        _ rotation: SIMD4<Float>,
        _ zoom: Float,
        _ target: SIMD3<Float>
    ) {
        var value = EditorSettings.Camera()
        value.preset = .perspective
        value.rotationX = Double(rotation.x)
        value.rotationY = Double(rotation.y)
        value.rotationZ = Double(rotation.z)
        value.rotationW = Double(rotation.w)
        value.zoom = Double(zoom)
        value.targetX = Double(target.x)
        value.targetY = Double(target.y)
        value.targetZ = Double(target.z)
        if isFrustumVisible {
            observerCamera = value
        } else {
            camera = value
        }
    }

    private func updateFraction(_ time: Duration) {
        guard !isScrubbing else { return }
        let wasComplete = fraction >= 1
        fraction = min(time / scrubDuration, 1)
        guard duration > .zero else { return }
        if !wasComplete, time >= duration {
            onPlaybackComplete()
        }
    }
}
