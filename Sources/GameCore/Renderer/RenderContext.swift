import Swift

public struct RenderContext: Sendable {
    public private(set) var sprites: [Sprite] = []

    public init() {}

    public mutating func sprite(_ sprite: Sprite) {
        sprites.append(sprite)
    }

    public mutating func fill(_ rect: Rect, color: Color) {
        sprite(
            Sprite(
                position: rect.origin,
                size: rect.size,
                material: .color(color)
            )
        )
    }

    public mutating func stroke(
        _ rect: Rect,
        color: Color,
        width: Double = 1
    ) {
        guard width > 0, rect.size.x > 0, rect.size.y > 0 else {
            return
        }

        let strokeWidth = min(width, rect.size.x / 2, rect.size.y / 2)
        let verticalHeight = max(rect.size.y - (strokeWidth * 2), 0)

        fill(
            Rect(
                x: rect.minX,
                y: rect.minY,
                width: rect.size.x,
                height: strokeWidth
            ),
            color: color
        )
        fill(
            Rect(
                x: rect.minX,
                y: rect.maxY - strokeWidth,
                width: rect.size.x,
                height: strokeWidth
            ),
            color: color
        )
        fill(
            Rect(
                x: rect.minX,
                y: rect.minY + strokeWidth,
                width: strokeWidth,
                height: verticalHeight
            ),
            color: color
        )
        fill(
            Rect(
                x: rect.maxX - strokeWidth,
                y: rect.minY + strokeWidth,
                width: strokeWidth,
                height: verticalHeight
            ),
            color: color
        )
    }
}
