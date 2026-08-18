import MetalKit
import PixlEditorSupport
import PixlMetal
import PixlParticles
import PixlRenderer
import SwiftUI

#if os(macOS)
private typealias PlatformGestureState = NSGestureRecognizer.State
#else
private typealias PlatformGestureState = UIGestureRecognizer.State
#endif

@MainActor
final class Coordinator: NSObject, MTKViewDelegate {
    private weak var view: MTKView?
    private var renderThread: RenderThread?
    private var system: System
    private var systemID: ObjectIdentifier
    private var isPaused: Bool
    private var duration: Duration
    private let navigation: CameraNavigation
    private var onCameraChange: (SIMD4<Float>, Float, SIMD3<Float>) -> Void
    private var onTimeChange: (Duration) -> Void
    private var pointLOD: PointLOD
    private var isGroundPlaneVisible: Bool
    private var cullingBounds: CullingBounds
    private var capturesDiagnostics: Bool
    private var seekTime: Duration?
    private var resetID: UInt64
    private var onFrame: (RenderDiagnostics) -> Void

    init(
        system: System,
        isPaused: Bool,
        duration: Duration,
        preset: CameraPreset,
        rotation: SIMD4<Float>,
        zoom: Float,
        target: SIMD3<Float>,
        observerCamera: EditorSettings.Camera?,
        pointLOD: PointLOD,
        isGroundPlaneVisible: Bool,
        isFrustumVisible: Bool,
        cullingBounds: CullingBounds,
        capturesDiagnostics: Bool,
        seekTime: Duration?,
        resetID: UInt64,
        onCameraChange: @escaping (SIMD4<Float>, Float, SIMD3<Float>) -> Void,
        onTimeChange: @escaping (Duration) -> Void,
        onFrame: @escaping (RenderDiagnostics) -> Void
    ) {
        self.system = system
        systemID = ObjectIdentifier(system)
        self.isPaused = isPaused
        self.duration = duration
        navigation = CameraNavigation(
            preset: preset,
            rotation: rotation,
            zoom: zoom,
            target: target,
            observerPose: observerCamera?.pose,
            isFrustumVisible: isFrustumVisible
        )
        self.onCameraChange = onCameraChange
        self.onTimeChange = onTimeChange
        self.pointLOD = pointLOD
        self.isGroundPlaneVisible = isGroundPlaneVisible
        self.cullingBounds = cullingBounds
        self.capturesDiagnostics = capturesDiagnostics
        self.seekTime = seekTime
        self.resetID = resetID
        self.onFrame = onFrame
    }

    func configure(_ view: ParticleMTKView) {
        self.view = view
        let layer = PixlMetal.Platform.configure(view)
        renderThread = RenderThread(layer: layer, system: system)
        view.delegate = self
        view.isPaused = isPaused
        view.enableSetNeedsDisplay = true
        view.installCameraGestures(target: self)
        view.onScroll = { [weak self] delta in self?.scroll(delta) }
    }

    func update(
        system: System,
        isPaused: Bool,
        duration: Duration,
        preset: CameraPreset,
        observerCamera: EditorSettings.Camera?,
        pointLOD: PointLOD,
        isGroundPlaneVisible: Bool,
        isFrustumVisible: Bool,
        cullingBounds: CullingBounds,
        capturesDiagnostics: Bool,
        seekTime: Duration?,
        resetID: UInt64,
        onCameraChange: @escaping (SIMD4<Float>, Float, SIMD3<Float>) -> Void,
        onTimeChange: @escaping (Duration) -> Void,
        onFrame: @escaping (RenderDiagnostics) -> Void
    ) {
        let replacement = ObjectIdentifier(system) != systemID
        if replacement {
            self.system = system
            systemID = ObjectIdentifier(system)
            renderThread?.replaceSystem(system)
        }
        self.isPaused = isPaused
        if duration != self.duration {
            self.duration = duration
            renderThread?.setDuration(duration)
        }
        navigation.update(
            preset: preset,
            observerPose: observerCamera?.pose,
            isFrustumVisible: isFrustumVisible
        )
        self.pointLOD = pointLOD
        self.isGroundPlaneVisible = isGroundPlaneVisible
        self.cullingBounds = cullingBounds
        self.capturesDiagnostics = capturesDiagnostics
        if resetID != self.resetID {
            renderThread?.seek(to: .zero)
        } else if let seekTime, replacement || seekTime != self.seekTime {
            renderThread?.seek(to: seekTime)
        }
        self.seekTime = seekTime
        self.resetID = resetID
        self.onCameraChange = onCameraChange
        self.onTimeChange = onTimeChange
        self.onFrame = onFrame
    }

    func draw(in view: MTKView) {
        guard let renderThread else { return }
        let result = renderThread.result()
        if let failure = result.failure {
            fatalError("Unable to render particles: \(failure)")
        }
        if let time = result.time {
            onTimeChange(time)
        }
        if let diagnostics = result.diagnostics { onFrame(diagnostics) }
        if navigation.advanceTransition() { commit() }
        let observerCamera = navigation.observerCamera
        let sceneCamera = navigation.sceneCamera
        let size = view.drawableSize.vector
        guard
            let observerViewport = observerCamera.viewport(for: size),
            let sceneViewport = sceneCamera.viewport(for: size)
        else { return }
        let viewProjection = observerViewport.viewProjection
        let cullingViewProjection = sceneViewport.viewProjection
        let cameraFrustum = navigation.frustum(
            viewport: sceneViewport,
            size: size
        )
        let editor = PixlEditorSupport.Frame(
            viewProjection: viewProjection,
            groundPlane: .init(
                isVisible: isGroundPlaneVisible,
                style: navigation.preset.groundPlaneStyle
            ),
            wireBox: .init(
                isVisible: cullingBounds.isVisible,
                center: [
                    0,
                    cullingBounds.baseHeight + cullingBounds.scale * 0.5,
                    0,
                ],
                size: .init(repeating: cullingBounds.scale)
            ),
            cameraFrustum: cameraFrustum
        )
        let frame = Mailbox.Frame(
            isPaused: isPaused,
            capturesDiagnostics: capturesDiagnostics,
            frameBudget: 1 / Double(max(view.preferredFramesPerSecond, 1)),
            pointLOD: pointLOD,
            editor: editor,
            cullingBounds: cullingBounds,
            cullingViewProjection: cullingViewProjection,
            viewProjection: viewProjection,
            viewport: .init(
                width: UInt32(view.drawableSize.width.rounded(.up)),
                height: UInt32(view.drawableSize.height.rounded(.up))
            )
        )
        renderThread.submit(frame)
        if navigation.isTransitioning, view.isPaused {
            DispatchQueue.main.async { [weak self] in self?.redraw() }
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard view.isPaused else { return }
#if os(macOS)
        view.setNeedsDisplay(view.bounds)
#else
        view.setNeedsDisplay()
#endif
    }

    private func redraw() {
        guard let view, view.isPaused else { return }
#if os(macOS)
        view.setNeedsDisplay(view.bounds)
#else
        view.setNeedsDisplay()
#endif
    }

    private func commit() {
        let pose = navigation.persistedPose
        onCameraChange(
            pose.rotation,
            pose.zoom,
            pose.target
        )
    }

    private func scroll(_ delta: Float) {
        guard let view else { return }
        navigation.scroll(delta, viewportSize: view.bounds.size.vector)
        redraw()
        commit()
    }

#if os(macOS)
    @objc func orbit(_ gesture: NSPanGestureRecognizer) {
        handlePan(
            state: gesture.state,
            x: Float(gesture.translation(in: gesture.view).x),
            y: -Float(gesture.translation(in: gesture.view).y)
        )
    }

    @objc func magnify(_ gesture: NSMagnificationGestureRecognizer) {
        handleZoom(
            state: gesture.state,
            scale: exp(Float(gesture.magnification))
        )
    }

    @objc func translate(_ gesture: NSPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        handleTranslation(
            state: gesture.state,
            translation: [Float(translation.x), Float(-translation.y)]
        )
    }
#else
    @objc func orbit(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        handlePan(state: gesture.state, x: Float(translation.x), y: Float(translation.y))
    }

    @objc func magnify(_ gesture: UIPinchGestureRecognizer) {
        handleZoom(
            state: gesture.state,
            scale: Float(gesture.scale)
        )
    }

    @objc func translate(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        handleTranslation(
            state: gesture.state,
            translation: [Float(translation.x), Float(translation.y)]
        )
    }
#endif

    private func handlePan(state: PlatformGestureState, x: Float, y: Float) {
        switch state {
        case .began:
            navigation.beginOrbit()
        case .changed:
            navigation.orbit(x: x, y: y)
            redraw()
        case .ended, .cancelled:
            navigation.endOrbit()
            commit()
        default:
            break
        }
    }

    private func handleZoom(
        state: PlatformGestureState,
        scale: Float
    ) {
        switch state {
        case .began:
            navigation.beginZoom()
        case .changed:
            guard let view else { return }
            navigation.zoom(
                scale: scale,
                viewportSize: view.bounds.size.vector
            )
            redraw()
        case .ended, .cancelled:
            navigation.endZoom()
            commit()
        default:
            break
        }
    }

    private func handleTranslation(
        state: PlatformGestureState,
        translation: SIMD2<Float>
    ) {
        switch state {
        case .began:
            navigation.beginTranslation()
        case .changed:
            guard let view else { return }
            navigation.translate(
                translation,
                viewportSize: view.bounds.size.vector
            )
            redraw()
        case .ended, .cancelled:
            navigation.endTranslation()
            commit()
        default:
            break
        }
    }

}

private extension CGSize {
    var vector: SIMD2<Float> { [Float(width), Float(height)] }
}

private extension EditorSettings.Camera {
    var pose: CameraPose {
        CameraPose(
            rotation: [
                Float(rotationX),
                Float(rotationY),
                Float(rotationZ),
                Float(rotationW),
            ],
            zoom: Float(zoom),
            target: [Float(targetX), Float(targetY), Float(targetZ)]
        )
    }
}

#if os(macOS)
extension Coordinator: NSGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
    ) -> Bool { true }
}
#else
extension Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }
}
#endif
