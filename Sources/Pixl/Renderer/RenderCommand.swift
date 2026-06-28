import Swift

public enum RenderCommand: Equatable, Sendable {
    case sprite(Sprite)
    case path(Path)
    case rect(Rect, Color, RenderLayer)
}

public extension RenderCommand {
    var layer: RenderLayer {
        switch self {
        case .sprite(let sprite):
            sprite.layer
        case .path(let path):
            path.layer
        case .rect(_, _, let layer):
            layer
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
            body(.sprite(sprite))
        case .path(let path):
            path.forEachPrimitive(body)
        case .rect(let rect, let color, _):
            body(.rect(rect, color))
        }
    }
}
