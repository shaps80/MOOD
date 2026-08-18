import PixlMath
import Swift

public final class CameraNavigation {
    private static let minimumZoom: Float = 0.001
    private static let maximumZoom: Float = 10
    private static let observerFarPadding: Float = 25_000

    public private(set) var preset: CameraPreset
    public private(set) var orbit: Orbit
    public private(set) var zoom: Float
    public private(set) var isFrustumVisible: Bool

    private var cullingCamera: Camera?
    private var cachedFrustum: (size: SIMD2<Float>, value: CameraFrustum)?
    private var scenePose: Pose?
    private var transition: Transition?
    private var startOrbit: Orbit?
    private var startZoom: Float?
    private var startTarget: SIMD3<Float>?

    public init(
        preset: CameraPreset,
        rotation: SIMD4<Float>,
        zoom: Float,
        target: SIMD3<Float>,
        observerPose: CameraPose?,
        isFrustumVisible: Bool,
        instant: ContinuousClock.Instant = .now
    ) {
        var orbit = CameraPreset.perspectiveOrbit
        orbit.rotation = normalize(Quat(vector: rotation))
        orbit.target = target
        self.preset = preset
        self.orbit = orbit
        self.zoom = zoom
        self.isFrustumVisible = isFrustumVisible
        let isFrustumActive = isFrustumVisible && preset == .perspective
        cullingCamera = isFrustumActive ? orbit.camera(zoom: zoom) : nil
        if isFrustumActive {
            scenePose = Pose(orbit: orbit, zoom: zoom)
            let destination = observerPose.map(Self.pose)
                ?? Pose(
                    orbit: orbit,
                    zoom: max(zoom * 0.7, Self.minimumZoom)
                )
            transition = Transition(
                from: Pose(orbit: orbit, zoom: zoom),
                to: destination,
                instant: instant,
                clearsCulling: false
            )
        }
    }

    public var observerCamera: Camera {
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

    public var sceneCamera: Camera {
        isFrustumActive ? cullingCamera ?? observerCamera : observerCamera
    }

    public var isTransitioning: Bool { transition != nil }

    public var persistedPose: CameraPose {
        CameraPose(
            rotation: orbit.rotation.vector,
            zoom: zoom,
            target: orbit.target
        )
    }

    public func update(
        preset: CameraPreset,
        observerPose: CameraPose?,
        isFrustumVisible: Bool,
        instant: ContinuousClock.Instant = .now
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
            if let observerPose {
                let pose = Self.pose(observerPose)
                orbit = pose.orbit
                zoom = pose.zoom
            }
        } else if !willBeActive, wasActive, isFrustumVisible {
            transition = nil
        } else if willBeActive, !wasActive {
            cullingCamera = observerCamera
            cachedFrustum = nil
            scenePose = Pose(orbit: orbit, zoom: zoom)
            let destination = observerPose.map(Self.pose)
                ?? Pose(
                    orbit: orbit,
                    zoom: max(zoom * 0.7, Self.minimumZoom)
                )
            beginTransition(
                to: destination,
                instant: instant,
                clearsCulling: false
            )
        } else if !willBeActive, wasActive, !isFrustumVisible, let scenePose {
            beginTransition(
                to: scenePose,
                instant: instant,
                clearsCulling: true
            )
        }
        self.preset = preset
        self.isFrustumVisible = isFrustumVisible
    }

    @discardableResult
    public func advanceTransition(
        at instant: ContinuousClock.Instant = .now
    ) -> Bool {
        guard let transition else { return false }
        let elapsed = Self.seconds(transition.start.duration(to: instant))
        let progress = min(Float(elapsed) / transition.duration, 1)
        let eased = progress * progress * (3 - 2 * progress)
        orbit.target = mix(
            transition.startPose.orbit.target,
            transition.endPose.orbit.target,
            eased
        )
        orbit.rotation = slerp(
            transition.startPose.orbit.rotation,
            transition.endPose.orbit.rotation,
            eased
        )
        zoom = mix(transition.startPose.zoom, transition.endPose.zoom, eased)
        guard progress >= 1 else { return false }
        self.transition = nil
        if transition.clearsCulling { clearCullingCamera() }
        return true
    }

    public func frustum(
        viewport: Camera.Viewport,
        size: SIMD2<Float>
    ) -> CameraFrustum {
        guard isFrustumActive, cullingCamera != nil else { return .init() }
        if let cachedFrustum, cachedFrustum.size == size {
            return cachedFrustum.value
        }
        let value = CameraFrustum(
            isVisible: isFrustumVisible,
            isPerspective: true,
            position: sceneCamera.position,
            inverseViewProjection: viewport.inverseViewProjection
        )
        cachedFrustum = (size, value)
        return value
    }

    public func scroll(_ delta: Float, viewportSize: SIMD2<Float>) {
        interruptTransition()
        zoom = min(
            max(zoom * exp(delta * 0.01), Self.minimumZoom),
            Self.maximumZoom
        )
        clamp(viewportSize: viewportSize)
    }

    public func beginOrbit() {
        interruptTransition()
        startOrbit = orbit
    }

    public func orbit(x: Float, y: Float) {
        guard preset == .perspective, var start = startOrbit else { return }
        start.rotate(yawBy: -x * 0.005, pitchBy: y * 0.005)
        orbit = start
    }

    public func endOrbit() { startOrbit = nil }

    public func beginZoom() {
        interruptTransition()
        startZoom = zoom
    }

    public func zoom(scale: Float, viewportSize: SIMD2<Float>) {
        guard let startZoom else { return }
        zoom = min(
            max(startZoom * scale, Self.minimumZoom),
            Self.maximumZoom
        )
        clamp(viewportSize: viewportSize)
    }

    public func endZoom() { startZoom = nil }

    public func beginTranslation() {
        interruptTransition()
        startTarget = orbit.target
    }

    public func translate(
        _ translation: SIMD2<Float>,
        viewportSize: SIMD2<Float>
    ) {
        guard
            preset == .perspective,
            let startTarget,
            viewportSize.y > 0
        else { return }
        orbit.target = startTarget
        orbit.pan(
            by: translation,
            viewportHeight: viewportSize.y,
            zoom: zoom
        )
        clamp(viewportSize: viewportSize)
    }

    public func endTranslation() { startTarget = nil }

    private func clamp(viewportSize: SIMD2<Float>) {
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
                height: GroundPlane.defaultHeight,
                extent: GroundPlane.defaultExtent,
                viewportSize: viewportSize,
                zoom: zoom
            )
        }
    }

    private func beginTransition(
        to pose: Pose,
        instant: ContinuousClock.Instant,
        clearsCulling: Bool
    ) {
        transition = Transition(
            from: Pose(orbit: orbit, zoom: zoom),
            to: pose,
            instant: instant,
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

    private static func pose(_ value: CameraPose) -> Pose {
        var orbit = CameraPreset.perspectiveOrbit
        orbit.rotation = normalize(Quat(vector: value.rotation))
        orbit.target = value.target
        return Pose(orbit: orbit, zoom: value.zoom)
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1e18
    }
}

private struct Pose {
    let orbit: Orbit
    let zoom: Float
}

private struct Transition {
    let startPose: Pose
    let endPose: Pose
    let start: ContinuousClock.Instant
    let duration: Float = 0.3
    let clearsCulling: Bool

    init(
        from start: Pose,
        to end: Pose,
        instant: ContinuousClock.Instant,
        clearsCulling: Bool
    ) {
        startPose = start
        endPose = end
        self.start = instant
        self.clearsCulling = clearsCulling
    }
}
