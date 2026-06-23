import Swift

public struct CameraConstraints: Equatable, Sendable {
    public var bounds: Rect?
    public var lockX: Double?
    public var lockY: Double?

    public init(
        bounds: Rect? = nil,
        lockX: Double? = nil,
        lockY: Double? = nil
    ) {
        self.bounds = bounds
        self.lockX = lockX
        self.lockY = lockY
    }

    func constrain(origin: Vec2, viewportSize: Vec2) -> Vec2 {
        var origin = origin

        if let lockX {
            origin = Vec2(x: lockX, y: origin.y)
        }

        if let lockY {
            origin = Vec2(x: origin.x, y: lockY)
        }

        guard let bounds else {
            return origin
        }

        let maxX = max(bounds.minX, bounds.maxX - viewportSize.x)
        let maxY = max(bounds.minY, bounds.maxY - viewportSize.y)

        return Vec2(
            x: clamp(origin.x, min: bounds.minX, max: maxX),
            y: clamp(origin.y, min: bounds.minY, max: maxY)
        )
    }
}
