import Swift

public struct RenderContext: Sendable {
    public private(set) var commands: [RenderCommand] = []

    public init() {}

    public mutating func removeAll(keepingCapacity: Bool = false) {
        commands.removeAll(keepingCapacity: keepingCapacity)
    }

    public mutating func sprite(_ sprite: Sprite) {
        commands.append(.sprite(sprite))
    }

    public mutating func fill(_ rect: Rect, color: Color) {
        commands.append(.rect(rect, color))
    }

    public mutating func stroke(
        _ rect: Rect,
        color: Color,
        width: Double = 1
    ) {
        commands.append(
            .strokeRect(
                rect,
                Stroke(color: color, width: width)
            )
        )
    }
}
