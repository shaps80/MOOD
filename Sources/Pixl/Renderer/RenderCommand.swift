import Swift

/// A game-facing render request before primitive expansion and batching.
///
/// Commands are the high-level output of gameplay rendering. Shape sprites are
/// expanded into paths, paths into shape primitives, then batches.
public enum RenderCommand: Equatable, Sendable {
    /// Draw a sprite at a world-space center point.
    case sprite(PositionedSprite)

    /// Draw a styled path.
    case path(Path)
}

public extension RenderCommand {
    /// The layer used for stable render ordering.
    var layer: RenderLayer {
        switch self {
        case .sprite(let positionedSprite):
            positionedSprite.sprite.layer
        case .path(let path):
            path.layer
        }
    }

    /// Number of low-level primitives this command expands into.
    var primitiveCount: Int {
        var count = 0

        forEachPrimitive { _ in
            count += 1
        }

        return count
    }

    /// Visits every primitive produced by this command.
    ///
    /// ```swift
    /// command.forEachPrimitive { primitive in
    ///     // Count, batch, or inspect each primitive.
    /// }
    /// ```
    func forEachPrimitive(_ body: (RenderPrimitive) -> Void) {
        switch self {
        case .sprite(let positionedSprite):
            positionedSprite.forEachPrimitive(body)
        case .path(let path):
            path.forEachPrimitive(body)
        }
    }
}

private extension PositionedSprite {
    func forEachPrimitive(_ body: (RenderPrimitive) -> Void) {
        let sprite = sprite

        switch sprite.material {
        case .sprite:
            body(.sprite(self))
        case .shape(let shape, let size):
            let scaledSize = size * sprite.scale
            let rect = Rect(
                x: position.x - (scaledSize.x / 2),
                y: position.y - (scaledSize.y / 2),
                width: scaledSize.x,
                height: scaledSize.y
            )
            let path = shape.path(in: rect)
            let style = RenderStyle(
                fill: .white,
                blendMode: sprite.blendMode,
                opacity: sprite.opacity,
                tint: sprite.tint
            )

            path
                .applying(style, layer: sprite.layer)
                .forEachPrimitive(body)
        }
    }
}
