import CoreGraphics
import PixlRenderer
import QuartzCore
import simd

final class CameraNavigation {
    private static let minimumZoom: Float = 0.001
    private static let maximumZoom: Float = 10
    private static let observerFarPadding: Float = 25_000

    private(set) var preset: CameraPreset
    private(set) var orbit: Orbit
    private(set) var zoom: Float
    private(set) var isFrustumVisible: Bool

    private var cullingCamera: Camera?
    private var cachedFrustum: (size: CGSize, value: CameraFrustum)?
    private var scenePose: Pose?
    private var transition: Transition?
    private var startOrbit: Orbit?
    private var startZoom: Float?
    private var startTarget: SIMD3<Float>?

    init(
        preset: CameraPreset,
        rotation: SIMD4<Float>,
        zoom: Float,
        target: SIMD3<Float>,
        observerCamera: EditorSettings.Camera?,
        isFrustumVisible: Bool
    ) {
        var orbit = CameraPreset.perspectiveOrbit
        if simd_length_squared(rotation) > 0 {
            orbit.rotation = simd_normalize(simd_quatf(vector: rotation))
        }
        orbit.target = target
        self.preset = preset
        self.orbit = orbit
        self.zoom = zoom
        self.isFrustumVisible = isFrustumVisible
        let isFrustumActive = isFrustumVisible && preset == .perspective
        cullingCamera = isFrustumActive ? orbit.camera(zoom: zoom) : nil
        if isFrustumActive {
            scenePose = Pose(orbit: orbit, zoom: zoom)
            let destination = if let observerCamera {
                Self.pose(observerCamera)
            } else {
                Pose(orbit: orbit, zoom: max(zoom * 0.7, Self.minimumZoom))
            }
            transition = Transition(
                from: Pose(orbit: orbit, zoom: zoom),
                to: destination,
                clearsCulling: false
            )
        }
    }

    var observerCamera: Camera {
        guard preset == .perspective else {
            var camera = preset.fixedCamera
            camera.projection = camera.projection.magnified(by: zoom)
            return camera
        }
        var camera = orbit.camera(zoom: zoom)
        if cullingCamera != nil {
            let observerDistance = orbit.distance / zoom
            camera.projection = camera.projection.extendingFarPlane(
                to: observerDistance + Self.observerFarPadding
            )
        }
        return camera
    }

    var sceneCamera: Camera {
        isFrustumActive ? cullingCamera ?? observerCamera : observerCamera
    }
    var isTransitioning: Bool { transition != nil }
    var persistedPose: (SIMD4<Float>, Float, SIMD3<Float>) {
        (orbit.rotation.vector, zoom, orbit.target)
    }

    func update(
        preset: CameraPreset,
        observerCamera: EditorSettings.Camera?,
        isFrustumVisible: Bool
    ) {
        let wasActive = isFrustumActive
        let willBeActive = isFrustumVisible && preset == .perspective
        let resumesAfterUnavailable = self.isFrustumVisible
            && self.preset != .perspective
            && willBeActive

        if resumesAfterUnavailable {
            if cullingCamera == nil {
                cullingCamera = orbit.camera(zoom: zoom)
                scenePose = Pose(orbit: orbit, zoom: zoom)
            }
            if let observerCamera {
                let pose = Self.pose(observerCamera)
                orbit = pose.orbit
                zoom = pose.zoom
            }
        } else if !willBeActive, wasActive, isFrustumVisible {
            transition = nil
        } else if willBeActive, !wasActive {
            cullingCamera = self.observerCamera
            cachedFrustum = nil
            scenePose = Pose(orbit: orbit, zoom: zoom)
            let destination = if let observerCamera {
                Self.pose(observerCamera)
            } else {
                Pose(orbit: orbit, zoom: max(zoom * 0.7, Self.minimumZoom))
            }
            beginTransition(to: destination, clearsCulling: false)
        } else if !willBeActive, wasActive, !isFrustumVisible, let scenePose {
            beginTransition(to: scenePose, clearsCulling: true)
        }
        self.preset = preset
        self.isFrustumVisible = isFrustumVisible
    }

    func advanceTransition() -> Bool {
        guard let transition else { return false }
        let elapsed = Float(CACurrentMediaTime() - transition.startTime)
        let progress = min(elapsed / transition.duration, 1)
        let eased = progress * progress * (3 - 2 * progress)
        orbit.target = simd_mix(
            transition.start.orbit.target,
            transition.end.orbit.target,
            SIMD3<Float>(repeating: eased)
        )
        orbit.rotation = simd_slerp(
            transition.start.orbit.rotation,
            transition.end.orbit.rotation,
            eased
        )
        zoom = simd_mix(transition.start.zoom, transition.end.zoom, eased)
        guard progress >= 1 else { return false }
        self.transition = nil
        if transition.clearsCulling { clearCullingCamera() }
        return true
    }

    func frustum(
        viewport: Camera.Viewport,
        size: CGSize
    ) -> CameraFrustum {
        guard isFrustumActive, cullingCamera != nil else { return .init() }
        if let cachedFrustum, cachedFrustum.size == size {
            return cachedFrustum.value
        }
        let value = CameraFrustum(
            isVisible: isFrustumVisible,
            isPerspective: true,
            position: sceneCamera.position,
            inverseViewProjection: Matrix4x4(
                simd_inverse(viewport.viewProjection)
            )
        )
        cachedFrustum = (size, value)
        return value
    }

    func scroll(_ delta: Float, viewportSize: CGSize) {
        interruptTransition()
        zoom = min(
            max(zoom * exp(delta * 0.01), Self.minimumZoom),
            Self.maximumZoom
        )
        clamp(viewportSize: viewportSize)
    }

    func beginOrbit() {
        interruptTransition()
        startOrbit = orbit
    }

    func orbit(x: Float, y: Float) {
        guard preset == .perspective, var start = startOrbit else { return }
        start.rotate(yawBy: -x * 0.005, pitchBy: y * 0.005)
        orbit = start
    }

    func endOrbit() { startOrbit = nil }

    func beginZoom() {
        interruptTransition()
        startZoom = zoom
    }

    func zoom(scale: Float, viewportSize: CGSize) {
        guard let startZoom else { return }
        zoom = min(
            max(startZoom * scale, Self.minimumZoom),
            Self.maximumZoom
        )
        clamp(viewportSize: viewportSize)
    }

    func endZoom() { startZoom = nil }

    func beginTranslation() {
        interruptTransition()
        startTarget = orbit.target
    }

    func translate(_ translation: SIMD2<Float>, viewportSize: CGSize) {
        guard
            preset == .perspective,
            let startTarget,
            viewportSize.height > 0
        else { return }
        orbit.target = startTarget
        orbit.pan(
            by: translation,
            viewportHeight: Float(viewportSize.height),
            zoom: zoom
        )
        clamp(viewportSize: viewportSize)
    }

    func endTranslation() { startTarget = nil }

    private func clamp(viewportSize: CGSize) {
        if
            let cullingCamera,
            let viewport = cullingCamera.viewport(for: viewportSize)
        {
            orbit.clamp(
                points: viewport.frustumCorners,
                viewportSize: viewportSize,
                zoom: zoom
            )
        } else {
            orbit.clampToGroundPlane(
                height: -100,
                extent: 500,
                viewportSize: viewportSize,
                zoom: zoom
            )
        }
    }

    private func beginTransition(to pose: Pose, clearsCulling: Bool) {
        transition = Transition(
            from: Pose(orbit: orbit, zoom: zoom),
            to: pose,
            clearsCulling: clearsCulling
        )
    }

    private func interruptTransition() {
        guard let transition else { return }
        self.transition = nil
        if transition.clearsCulling { clearCullingCamera() }
    }

    private func clearCullingCamera() {
        cullingCamera = nil
        cachedFrustum = nil
        scenePose = nil
    }

    private var isFrustumActive: Bool {
        isFrustumVisible && preset == .perspective
    }

    private static func pose(_ camera: EditorSettings.Camera) -> Pose {
        var orbit = CameraPreset.perspectiveOrbit
        let rotation = SIMD4<Float>(
            Float(camera.rotationX),
            Float(camera.rotationY),
            Float(camera.rotationZ),
            Float(camera.rotationW)
        )
        if simd_length_squared(rotation) > 0 {
            orbit.rotation = simd_normalize(simd_quatf(vector: rotation))
        }
        orbit.target = [
            Float(camera.targetX),
            Float(camera.targetY),
            Float(camera.targetZ),
        ]
        return Pose(orbit: orbit, zoom: Float(camera.zoom))
    }
}

private struct Pose {
    let orbit: Orbit
    let zoom: Float
}

private struct Transition {
    let start: Pose
    let end: Pose
    let startTime = CACurrentMediaTime()
    let duration: Float = 0.3
    let clearsCulling: Bool

    init(from start: Pose, to end: Pose, clearsCulling: Bool) {
        self.start = start
        self.end = end
        self.clearsCulling = clearsCulling
    }
}

extension Matrix4x4 {
    init(_ matrix: simd_float4x4) {
        self.init(
            x: matrix.columns.0,
            y: matrix.columns.1,
            z: matrix.columns.2,
            w: matrix.columns.3
        )
    }
}
