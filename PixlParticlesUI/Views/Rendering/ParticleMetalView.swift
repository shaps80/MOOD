import MetalKit
import PixlEditorSupport
import PixlParticles
import PixlRenderer
import SwiftUI

#if os(macOS)
private typealias PlatformViewRepresentable = NSViewRepresentable
#else
private typealias PlatformViewRepresentable = UIViewRepresentable
#endif

struct ParticleMetalView: PlatformViewRepresentable {
    let system: System
    let isPaused: Bool
    let duration: Duration
    let cameraPreset: CameraPreset
    let rotation: SIMD4<Float>
    let zoom: Float
    let target: SIMD3<Float>
    let observerCamera: EditorSettings.Camera?
    let pointLOD: PointLOD
    let isGroundPlaneVisible: Bool
    let isFrustumVisible: Bool
    let cullingBounds: CullingBounds
    let capturesDiagnostics: Bool
    let seekTime: Duration?
    let resetID: UInt64
    let onCameraChange: (SIMD4<Float>, Float, SIMD3<Float>) -> Void
    let onTimeChange: (Duration) -> Void
    let onFrame: (RenderDiagnostics) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            system: system,
            isPaused: isPaused,
            duration: duration,
            preset: cameraPreset,
            rotation: rotation,
            zoom: zoom,
            target: target,
            observerCamera: observerCamera,
            pointLOD: pointLOD,
            isGroundPlaneVisible: isGroundPlaneVisible,
            isFrustumVisible: isFrustumVisible,
            cullingBounds: cullingBounds,
            capturesDiagnostics: capturesDiagnostics,
            seekTime: seekTime,
            resetID: resetID,
            onCameraChange: onCameraChange,
            onTimeChange: onTimeChange,
            onFrame: onFrame
        )
    }

#if os(macOS)
    func makeNSView(context: Context) -> MTKView { makeView(context) }
    func updateNSView(_ view: MTKView, context: Context) { update(view, context) }
#else
    func makeUIView(context: Context) -> MTKView { makeView(context) }
    func updateUIView(_ view: MTKView, context: Context) { update(view, context) }
#endif

    private func makeView(_ context: Context) -> MTKView {
        let view = ParticleMTKView(frame: .zero, device: nil)
        context.coordinator.configure(view)
        return view
    }

    private func update(_ view: MTKView, _ context: Context) {
        context.coordinator.update(
            system: system,
            isPaused: isPaused,
            duration: duration,
            preset: cameraPreset,
            observerCamera: observerCamera,
            pointLOD: pointLOD,
            isGroundPlaneVisible: isGroundPlaneVisible,
            isFrustumVisible: isFrustumVisible,
            cullingBounds: cullingBounds,
            capturesDiagnostics: capturesDiagnostics,
            seekTime: seekTime,
            resetID: resetID,
            onCameraChange: onCameraChange,
            onTimeChange: onTimeChange,
            onFrame: onFrame
        )
        if view.isPaused != isPaused { view.isPaused = isPaused }
        guard isPaused else { return }
#if os(macOS)
        view.setNeedsDisplay(view.bounds)
#else
        view.setNeedsDisplay()
#endif
    }
}
