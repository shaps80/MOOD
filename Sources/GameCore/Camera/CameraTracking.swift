import Swift

public enum CameraTracking: Equatable, Sendable {
    case snap

    func resolve(current: Vec2, desired: Vec2) -> Vec2 {
        switch self {
        case .snap:
            return desired
        }
    }
}
