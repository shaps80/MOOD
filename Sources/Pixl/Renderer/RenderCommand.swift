import Swift

public enum RenderCommand: Equatable, Sendable {
    case sprite(PositionedSprite)
    case path(Path)
}

public extension RenderCommand {
    var layer: RenderLayer {
        switch self {
        case .sprite(let positionedSprite):
            positionedSprite.sprite.layer
        case .path(let path):
            path.layer
        }
    }

    var primitiveCount: Int {
        var count = 0

        forEachPrimitive { _ in
            count += 1
        }

        return count
    }

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
