import Swift

/// Describes how the camera moves toward the desired origin.
///
/// Tracking is mutually exclusive. A camera snaps, smooth-follows, or performs
/// a scripted transition. It should not combine multiple movement policies at
/// once.
///
/// Current modes:
///
/// ```text
/// snap:
///   current origin ---------> desired origin
///                same frame
///
/// smooth:
///   current origin -----> desired origin
///                 speed * delta per update
/// ```
public enum CameraTracking: Equatable, Sendable {
    /// Immediately sets the camera origin to the desired origin.
    case snap

    /// Moves toward the desired origin by at most `speed * delta` each update.
    case smooth(speed: Double)

    func resolve(current: Vec2, desired: Vec2, delta: Double) -> Vec2 {
        switch self {
        case .snap:
            return desired
        case .smooth(let speed):
            return current.moving(
                toward: desired,
                by: max(speed, 0) * max(delta, 0)
            )
        }
    }
}
