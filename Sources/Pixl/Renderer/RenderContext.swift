import Swift

/// Collects draw commands for a game frame.
///
/// Game code writes into a `RenderContext`; Pixl then sorts and batches those
/// commands before platform renderers upload them.
///
/// ```swift
/// var context = RenderContext()
/// context.draw(playerSprite, at: player.position)
/// context.fill(Rect(x: 0, y: 0, width: 16, height: 16), color: .red)
/// context.sortCommands()
/// ```
public struct RenderContext: Sendable {
    /// Commands recorded for the current frame.
    public private(set) var commands: [RenderCommand] = []

    /// Creates an empty render context.
    public init() {}

    /// Removes all commands.
    ///
    /// - Parameter keepingCapacity: Whether to keep existing storage allocated
    ///   for reuse next frame.
    public mutating func removeAll(keepingCapacity: Bool = false) {
        commands.removeAll(keepingCapacity: keepingCapacity)
    }

    mutating func append(contentsOf commands: [RenderCommand]) {
        self.commands.append(contentsOf: commands)
    }

    /// Sorts commands by layer while preserving insertion order within a layer.
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

    /// Records a sprite draw at a world-space center point.
    ///
    /// ```swift
    /// context.draw(sprite, at: entity.position)
    /// ```
    public mutating func draw(_ sprite: Sprite, at position: Vec2) {
        commands.append(
            .sprite(PositionedSprite(sprite: sprite, position: position))
        )
    }

    /// Records a styled path draw.
    public mutating func draw(
        _ path: Path,
        style: RenderStyle = RenderStyle(),
        layer: RenderLayer = 0
    ) {
        commands.append(
            .path(path.applying(style, layer: layer))
        )
    }

    /// Records a shape draw by first building its path in `rect`.
    ///
    /// ```swift
    /// context.draw(Capsule(), in: playerBounds, style: style)
    /// ```
    public mutating func draw<S: Shape>(
        _ shape: S,
        in rect: Rect,
        style: RenderStyle = RenderStyle(),
        layer: RenderLayer = 0
    ) {
        draw(shape.path(in: rect), style: style, layer: layer)
    }

    /// Records a filled rectangle.
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

    /// Records a stroked rectangle.
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
