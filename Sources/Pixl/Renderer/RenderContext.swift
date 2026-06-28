import Swift

public struct RenderContext: Sendable {
    public private(set) var commands: [RenderCommand] = []

    public init() {}

    public mutating func removeAll(keepingCapacity: Bool = false) {
        commands.removeAll(keepingCapacity: keepingCapacity)
    }

    mutating func append(contentsOf commands: [RenderCommand]) {
        self.commands.append(contentsOf: commands)
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

    public mutating func draw(_ sprite: Sprite) {
        commands.append(
            .sprite(sprite)
        )
    }

    public mutating func draw(
        _ path: Path,
        style: RenderStyle = RenderStyle(),
        layer: RenderLayer = 0
    ) {
        commands.append(
            .path(path.applying(style, layer: layer))
        )
    }

    public mutating func draw<S: Shape>(
        _ shape: S,
        in rect: Rect,
        style: RenderStyle = RenderStyle(),
        layer: RenderLayer = 0
    ) {
        draw(shape.path(in: rect), style: style, layer: layer)
    }

    public mutating func fill(
        _ rect: Rect,
        color: Color,
        layer: RenderLayer = 0
    ) {
        draw(
            Path(rect),
            style: RenderStyle(fill: color),
            layer: layer
        )
    }

    public mutating func stroke(
        _ rect: Rect,
        color: Color,
        width: Double = 1,
        layer: RenderLayer = 0
    ) {
        draw(
            Path(rect),
            style: RenderStyle(
                fill: nil,
                stroke: color,
                strokeStyle: StrokeStyle(lineWidth: width)
            ),
            layer: layer
        )
    }
}
