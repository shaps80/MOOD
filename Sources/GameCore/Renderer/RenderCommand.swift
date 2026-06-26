import Swift

public enum RenderCommand: Equatable, Sendable {
    case sprite(Sprite)
    case rect(Rect, Color)
    case strokeRect(Rect, Stroke)
}

public extension RenderCommand {
    func forEachPrimitive(_ body: (RenderPrimitive) -> Void) {
        switch self {
        case .sprite(let sprite):
            body(.sprite(sprite))
        case .rect(let rect, let color):
            body(.rect(rect, color))
        case .strokeRect(let rect, let stroke):
            forEachStrokePrimitive(rect: rect, stroke: stroke, body)
        }
    }

    private func forEachStrokePrimitive(
        rect: Rect,
        stroke: Stroke,
        _ body: (RenderPrimitive) -> Void
    ) {
        guard stroke.width > 0, rect.size.x > 0, rect.size.y > 0 else {
            return
        }

        let width = min(stroke.width, rect.size.x / 2, rect.size.y / 2)
        let verticalHeight = max(rect.size.y - (width * 2), 0)

        body(.rect(
            Rect(x: rect.minX, y: rect.minY, width: rect.size.x, height: width),
            stroke.color
        ))
        body(.rect(
            Rect(x: rect.minX, y: rect.maxY - width, width: rect.size.x, height: width),
            stroke.color
        ))
        body(.rect(
            Rect(x: rect.minX, y: rect.minY + width, width: width, height: verticalHeight),
            stroke.color
        ))
        body(.rect(
            Rect(x: rect.maxX - width, y: rect.minY + width, width: width, height: verticalHeight),
            stroke.color
        ))
    }
}
