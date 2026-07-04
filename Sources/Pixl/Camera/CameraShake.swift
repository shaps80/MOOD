import Swift

/// A transient presentation shake applied by `CameraRig`.
///
/// Shake is layered on top of the rig's base `transform`. It affects rendering
/// only and decays over `duration`.
///
/// ```swift
/// context.camera.shake(.init(duration: 0.08, amplitude: 3))
/// ```
public struct CameraShake: Equatable, Sendable {
    /// How long the shake lasts in simulation seconds.
    public var duration: Double

    /// Maximum translation offset in logical pixels.
    public var amplitude: Double

    /// Maximum roll angle.
    public var rotation: Angle

    /// Oscillation rate in cycles per second.
    public var frequency: Double

    /// Creates a camera shake.
    public init(
        duration: Double = 0.1,
        amplitude: Double = .init((5...10).randomElement()!),
        rotation: Angle = .degrees(.init((25...75).randomElement()!) / 100.0),
        frequency: Double = .init((20...60).randomElement()!)
    ) {
        self.duration = duration
        self.amplitude = amplitude
        self.rotation = rotation
        self.frequency = frequency
    }
}
