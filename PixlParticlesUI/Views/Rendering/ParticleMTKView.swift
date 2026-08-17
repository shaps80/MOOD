import MetalKit

#if os(macOS)
final class ParticleMTKView: MTKView {
    var onScroll: ((Float) -> Void)?

    func installCameraGestures(target: Coordinator) {
        let orbit = NSPanGestureRecognizer(
            target: target,
            action: #selector(Coordinator.orbit(_:))
        )
        orbit.buttonMask = 1
        addGestureRecognizer(orbit)

        let translation = NSPanGestureRecognizer(
            target: target,
            action: #selector(Coordinator.translate(_:))
        )
        translation.buttonMask = 2
        addGestureRecognizer(translation)

        let magnification = NSMagnificationGestureRecognizer(
            target: target,
            action: #selector(Coordinator.magnify(_:))
        )
        magnification.delegate = target
        addGestureRecognizer(magnification)
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(Float(event.scrollingDeltaY))
    }
}
#else
final class ParticleMTKView: MTKView {
    var onScroll: ((Float) -> Void)?

    func installCameraGestures(target: Coordinator) {
        let orbit = UIPanGestureRecognizer(
            target: target,
            action: #selector(Coordinator.orbit(_:))
        )
        orbit.maximumNumberOfTouches = 1
        addGestureRecognizer(orbit)

        let translation = UIPanGestureRecognizer(
            target: target,
            action: #selector(Coordinator.translate(_:))
        )
        translation.minimumNumberOfTouches = 2
        translation.maximumNumberOfTouches = 2
        translation.delegate = target
        addGestureRecognizer(translation)

        let pinch = UIPinchGestureRecognizer(
            target: target,
            action: #selector(Coordinator.magnify(_:))
        )
        pinch.delegate = target
        addGestureRecognizer(pinch)
    }
}
#endif
