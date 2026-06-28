import Swift

public struct PresentationViewport: Equatable, Sendable {
    public let rect: Rect

    public init(containerSize: Vec2, logicalResolution: Vec2) {
        let scale = min(
            containerSize.x / logicalResolution.x,
            containerSize.y / logicalResolution.y
        )
        let width = max(1, (logicalResolution.x * scale).rounded())
        let height = max(1, (logicalResolution.y * scale).rounded())

        self.rect = Rect(
            x: ((containerSize.x - width) / 2).rounded(),
            y: ((containerSize.y - height) / 2).rounded(),
            width: width,
            height: height
        )
    }
}

public extension Rect {
    var integral: Rect {
        let minX = origin.x.rounded()
        let minY = origin.y.rounded()
        let maxX = (origin.x + size.x).rounded()
        let maxY = (origin.y + size.y).rounded()

        return Rect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX),
            height: max(0, maxY - minY)
        )
    }
}
