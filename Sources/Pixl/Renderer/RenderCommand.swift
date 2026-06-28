import Swift

public enum RenderCommand: Equatable, Sendable {
    case sprite(Sprite)
    case path(Path)
}

public extension RenderCommand {
    var layer: RenderLayer {
        switch self {
        case .sprite(let sprite):
            sprite.layer
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
        case .sprite(let sprite):
            sprite.forEachPrimitive(body)
        case .path(let path):
            path.forEachPrimitive(body)
        }
    }
}

private extension Sprite {
    func forEachPrimitive(_ body: (RenderPrimitive) -> Void) {
        switch material {
        case .sprite:
            body(.sprite(self))
        case .shape(let shape):
            let rect = Rect(origin: position, size: size)
            let path = shape.path(in: rect)
            let style = RenderStyle(
                fill: .white,
                blendMode: blendMode,
                opacity: opacity,
                tint: tint
            )

            path
                .applying(style, layer: layer)
                .forEachPrimitive(body)
        }
    }
}
