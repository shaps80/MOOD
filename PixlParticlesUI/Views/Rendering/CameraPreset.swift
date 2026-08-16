import simd

enum CameraPreset: Hashable {
    case perspective
    case isometric
    case front

    var groundPlaneStyle: GroundPlane.Style {
        self == .front ? .horizon : .grid
    }

    static let perspectiveOrbit = Orbit(
        target: .zero,
        distance: 600,
        yaw: .pi * 34 / 180,
        pitch: .pi * 25 / 180,
        projection: .perspective(
            verticalFieldOfView: .pi * 50 / 180,
            near: 0.1,
            far: 10_000
        )
    )

    var fixedCamera: Camera {
        switch self {
        case .perspective:
            Self.perspectiveOrbit.camera()

        case .isometric:
            Self.isometricCamera

        case .front:
            Self.frontCamera
        }
    }

    private static let isometricCamera = Camera(
        orbiting: .zero,
        distance: 700,
        yaw: .pi / 4,
        pitch: atan(1 / sqrt(2)),
        projection: .orthographic(
            halfHeight: 175,
            near: 0.1,
            far: 2_000
        )
    )

    private static let frontCamera = Camera(
        orbiting: .zero,
        distance: 600,
        yaw: 0,
        pitch: 0,
        projection: .orthographic(
            halfHeight: 175,
            near: 0.1,
            far: 2_000
        )
    )
}
