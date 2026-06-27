import Swift

/// Describes how the camera moves toward the desired origin.
///
/// Tracking is mutually exclusive. A camera snaps, smooth-follows, or performs
/// a scripted transition. It should not combine multiple movement policies at
/// once.
///
/// Current implementation:
///
/// ```text
/// snap:
///   current origin ---------> desired origin
///                same frame
/// ```
///
/// Future modes can add smooth movement or scripted transitions once gameplay
/// needs camera pans, reveals, or tuned follow behavior.
public enum CameraTracking: Equatable, Sendable {
    /// Immediately sets the camera origin to the desired origin.
    case snap

    func resolve(current: Vec2, desired: Vec2) -> Vec2 {
        switch self {
        case .snap:
            return desired
        }
    }
}
