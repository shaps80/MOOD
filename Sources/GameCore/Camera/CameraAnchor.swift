import Swift

public enum CameraAnchor: Equatable, Sendable {
    case point(Vec2)
    case entities([Entity.ID])

    func center(anchorBounds: (Entity.ID) -> Rect?) -> Vec2? {
        switch self {
        case .point(let point):
            return point
        case .entities(let ids):
            guard !ids.isEmpty else {
                return nil
            }

            var center = Vec2.zero
            var count = 0

            for id in ids {
                guard let bounds = anchorBounds(id) else {
                    continue
                }

                center = Vec2(
                    x: center.x + bounds.center.x,
                    y: center.y + bounds.center.y
                )
                count += 1
            }

            guard count > 0 else {
                return nil
            }

            return Vec2(
                x: center.x / Double(count),
                y: center.y / Double(count)
            )
        }
    }
}
