import PixlMath
import Swift

public enum CameraPreset: String, Codable, Hashable, Sendable {
    case perspective
    case isometric
    case front

    public var groundPlaneStyle: GroundPlane.Style {
        self == .front ? .horizon : .grid
    }

    public static let perspectiveOrbit = Orbit(
        target: .zero,
        distance: 400,
        yaw: .pi * 34 / 180,
        pitch: .pi * 25 / 180,
        projection: .perspective(
            verticalFieldOfView: .pi * 50 / 180,
            near: 0.1,
            far: 10_000
        )
    )

    public static var perspectivePose: CameraPose {
        CameraPose(
            rotation: perspectiveOrbit.rotation.vector,
            zoom: 1,
            target: perspectiveOrbit.target
        )
    }

    public var fixedCamera: Camera {
        switch self {
        case .perspective:
            Self.perspectiveOrbit.camera()
        case .isometric:
            Self.isometricOrbit.camera()
        case .front:
            Self.frontOrbit.camera()
        }
    }

    private static let isometricOrbit = Orbit(
        target: .zero,
        distance: 700,
        yaw: .pi / 4,
        pitch: atan(1 / Float(2).squareRoot()),
        projection: .orthographic(
            halfHeight: 175,
            near: 0.1,
            far: 2_000
        )
    )

    private static let frontOrbit = Orbit(
        target: .zero,
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
