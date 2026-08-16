import MetalKit
import PixlMetal
import PixlParticles
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
    private let renderer: PixlMetal.Renderer
    private weak var view: MTKView?
    private var system: System
    private var isPaused: Bool
    private var preset: CameraPreset
    private var orbit: Orbit
    private var zoom: Float
    private var startOrbit: Orbit?
    private var startZoom: Float?
    private var onCameraChange: (Float, Float, Float) -> Void
    private var onTimeChange: (Duration) -> Void

    init(
        system: System,
        isPaused: Bool,
        preset: CameraPreset,
        yaw: Float,
        pitch: Float,
        zoom: Float,
        onCameraChange: @escaping (Float, Float, Float) -> Void,
        onTimeChange: @escaping (Duration) -> Void
    ) {
        do { renderer = try PixlMetal.Renderer() }
        catch { fatalError("Unable to create Metal renderer: \(error)") }
        var orbit = CameraPreset.perspectiveOrbit
        orbit.yaw = yaw
        orbit.pitch = pitch
        self.system = system
        self.isPaused = isPaused
        self.preset = preset
        self.orbit = orbit
        self.zoom = zoom
        self.onCameraChange = onCameraChange
        self.onTimeChange = onTimeChange
    }

    func configure(_ view: ParticleMTKView) {
        self.view = view
        renderer.configure(view)
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
        onCameraChange: @escaping (Float, Float, Float) -> Void,
        onTimeChange: @escaping (Duration) -> Void
    ) {
        self.system = system
        self.isPaused = isPaused
        self.preset = preset
        self.onCameraChange = onCameraChange
        self.onTimeChange = onTimeChange
    }

    func draw(in view: MTKView) {
        guard let viewport = camera.viewport(for: view.drawableSize) else { return }
        let sample = system.sample(at: .now, isPaused: isPaused)
        do {
            try renderer.render(
                system,
                interpolation: sample.interpolation,
                viewProjection: viewport.viewProjection,
                in: view
            )
            onTimeChange(sample.time)
        } catch { fatalError("Unable to render particles: \(error)") }
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
            y: Float(gesture.translation(in: gesture.view).y)
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
