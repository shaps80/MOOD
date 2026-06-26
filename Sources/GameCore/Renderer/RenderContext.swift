import Swift

public struct RenderContext: Sendable {
    public private(set) var commands: [RenderCommand] = []

    public init() {}

    public mutating func removeAll(keepingCapacity: Bool = false) {
        commands.removeAll(keepingCapacity: keepingCapacity)
    }

    public mutating func sortCommands() {
        commands = commands.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.layer != rhs.element.layer {
                    return lhs.element.layer < rhs.element.layer
                }

                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    public mutating func sprite(
        _ sprite: Sprite,
        layer: Layer = .world
    ) {
        commands.append(
            .sprite(
                sprite,
                layer
            )
        )
    }

    public mutating func fill(
        _ rect: Rect,
        color: Color,
        layer: Layer = .world
    ) {
        commands.append(
            .rect(
                rect,
                color,
                layer
            )
        )
    }

    public mutating func stroke(
        _ rect: Rect,
        color: Color,
        width: Double = 1,
        layer: Layer = .world
    ) {
        commands.append(
            .strokeRect(
                rect,
                Stroke(color: color, width: width),
                layer
            )
        )
    }
}
