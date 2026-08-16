import MetalKit
import PixlMetal
import PixlParticles
import PixlRenderer
import SwiftUI

#if os(macOS)
private typealias PlatformViewRepresentable = NSViewRepresentable
private typealias PlatformGestureState = NSGestureRecognizer.State
#else
private typealias PlatformViewRepresentable = UIViewRepresentable
private typealias PlatformGestureState = UIGestureRecognizer.State
#endif
struct ParticleMetalView: PlatformViewRepresentable {
    let system: System
    let isPaused: Bool
    let cameraPreset: CameraPreset
    let yaw: Float
    let pitch: Float
    let zoom: Float
    let pointLOD: PointLOD
    let seekTime: Duration?
    let onCameraChange: (Float, Float, Float) -> Void
    let onTimeChange: (Duration) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            system: system,
            isPaused: isPaused,
            preset: cameraPreset,
            yaw: yaw,
            pitch: pitch,
            zoom: zoom,
            pointLOD: pointLOD,
            seekTime: seekTime,
            onCameraChange: onCameraChange,
            onTimeChange: onTimeChange
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
            preset: cameraPreset,
            pointLOD: pointLOD,
            seekTime: seekTime,
            onCameraChange: onCameraChange,
            onTimeChange: onTimeChange
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

@MainActor
final class Coordinator: NSObject, MTKViewDelegate {
    private weak var view: MTKView?
    private var renderThread: RenderThread?
    private var system: System
    private var systemID: ObjectIdentifier
    private var isPaused: Bool
    private var preset: CameraPreset
    private var orbit: Orbit
    private var zoom: Float
    private var startOrbit: Orbit?
    private var startZoom: Float?
    private var onCameraChange: (Float, Float, Float) -> Void
    private var onTimeChange: (Duration) -> Void
    private var pointLOD: PointLOD
    private var seekTime: Duration?

    init(
        system: System,
        isPaused: Bool,
        preset: CameraPreset,
        yaw: Float,
        pitch: Float,
        zoom: Float,
        pointLOD: PointLOD,
        seekTime: Duration?,
        onCameraChange: @escaping (Float, Float, Float) -> Void,
        onTimeChange: @escaping (Duration) -> Void
    ) {
        var orbit = CameraPreset.perspectiveOrbit
        orbit.yaw = yaw
        orbit.pitch = pitch
        self.system = system
        systemID = ObjectIdentifier(system)
        self.isPaused = isPaused
        self.preset = preset
        self.orbit = orbit
        self.zoom = zoom
        self.onCameraChange = onCameraChange
        self.onTimeChange = onTimeChange
        self.pointLOD = pointLOD
        self.seekTime = seekTime
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
        preset: CameraPreset,
        pointLOD: PointLOD,
        seekTime: Duration?,
        onCameraChange: @escaping (Float, Float, Float) -> Void,
        onTimeChange: @escaping (Duration) -> Void
    ) {
        let replacement = ObjectIdentifier(system) != systemID
        if replacement {
            self.system = system
            systemID = ObjectIdentifier(system)
            renderThread?.replaceSystem(system)
        }
        self.isPaused = isPaused
        self.preset = preset
        self.pointLOD = pointLOD
        if let seekTime, replacement || seekTime != self.seekTime {
            renderThread?.seek(to: seekTime)
        }
        self.seekTime = seekTime
        self.onCameraChange = onCameraChange
        self.onTimeChange = onTimeChange
    }

    func draw(in view: MTKView) {
        guard let renderThread else { return }
        let result = renderThread.result()
        if let failure = result.failure {
            fatalError("Unable to render particles: \(failure)")
        }
        if let time = result.time { onTimeChange(time) }
        let camera = camera
        guard let viewport = camera.viewport(for: view.drawableSize) else { return }
        let viewProjection = Matrix4x4(viewport.viewProjection)
        renderThread.submit(
            .init(
                isPaused: isPaused,
                pointLOD: pointLOD,
                groundPlane: .init(
                    isVisible: true,
                    style: preset.groundPlaneStyle,
                    viewProjection: viewProjection
                ),
                viewProjection: viewProjection,
                viewport: .init(
                    width: UInt32(view.drawableSize.width.rounded(.up)),
                    height: UInt32(view.drawableSize.height.rounded(.up))
                )
            )
        )
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private var camera: Camera {
        guard preset == .perspective else {
            var camera = preset.fixedCamera
            camera.projection = camera.projection.magnified(by: zoom)
            return camera
        }
        return orbit.camera(zoom: zoom)
    }

    private func redraw() {
        guard let view, view.isPaused else { return }
#if os(macOS)
        view.setNeedsDisplay(view.bounds)
#else
        view.setNeedsDisplay()
#endif
    }

    private func commit() { onCameraChange(orbit.yaw, orbit.pitch, zoom) }

    private func scroll(_ delta: Float) {
        zoom = min(max(zoom * exp(delta * 0.01), 0.1), 10)
        redraw()
        commit()
    }

#if os(macOS)
    @objc func pan(_ gesture: NSPanGestureRecognizer) {
        handlePan(
            state: gesture.state,
            x: Float(gesture.translation(in: gesture.view).x),
            y: -Float(gesture.translation(in: gesture.view).y)
        )
    }

    @objc func magnify(_ gesture: NSMagnificationGestureRecognizer) {
        handleZoom(state: gesture.state, scale: exp(Float(gesture.magnification)))
    }
#else
    @objc func pan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        handlePan(state: gesture.state, x: Float(translation.x), y: Float(translation.y))
    }

    @objc func magnify(_ gesture: UIPinchGestureRecognizer) {
        handleZoom(state: gesture.state, scale: Float(gesture.scale))
    }
#endif

    private func handlePan(state: PlatformGestureState, x: Float, y: Float) {
        guard preset == .perspective else { return }
        switch state {
        case .began:
            startOrbit = orbit
        case .changed:
            guard var start = startOrbit else { return }
            start.rotate(yawBy: -x * 0.005, pitchBy: y * 0.005)
            orbit = start
            redraw()
        case .ended, .cancelled:
            startOrbit = nil
            commit()
        default:
            break
        }
    }

    private func handleZoom(state: PlatformGestureState, scale: Float) {
        switch state {
        case .began:
            startZoom = zoom
        case .changed:
            guard let startZoom else { return }
            zoom = min(max(startZoom * scale, 0.1), 10)
            redraw()
        case .ended, .cancelled:
            startZoom = nil
            commit()
        default:
            break
        }
    }
}

private extension Matrix4x4 {
    init(_ matrix: simd_float4x4) {
        self.init(
            x: matrix.columns.0,
            y: matrix.columns.1,
            z: matrix.columns.2,
            w: matrix.columns.3
        )
    }
}

#if os(macOS)
final class ParticleMTKView: MTKView {
    var onScroll: ((Float) -> Void)?
    func installCameraGestures(target: Coordinator) {
        addGestureRecognizer(NSPanGestureRecognizer(target: target, action: #selector(Coordinator.pan(_:))))
        addGestureRecognizer(NSMagnificationGestureRecognizer(target: target, action: #selector(Coordinator.magnify(_:))))
    }
    override func scrollWheel(with event: NSEvent) {
        onScroll?(Float(event.scrollingDeltaY))
    }
}
#else
final class ParticleMTKView: MTKView {
    var onScroll: ((Float) -> Void)?
    func installCameraGestures(target: Coordinator) {
        addGestureRecognizer(UIPanGestureRecognizer(target: target, action: #selector(Coordinator.pan(_:))))
        addGestureRecognizer(UIPinchGestureRecognizer(target: target, action: #selector(Coordinator.magnify(_:))))
    }
}
#endif
