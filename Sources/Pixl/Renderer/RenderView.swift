import Swift

public struct RenderView: Equatable, Sendable {
    public let origin: Vec2
    public let size: Vec2
    public let padding: EdgeInsets

    public init(
        origin: Vec2,
        size: Vec2,
        padding: EdgeInsets = .zero
    ) {
        self.origin = origin
        self.size = size
        self.padding = padding
    }

    public var bounds: Rect {
        Rect(origin: origin, size: size)
    }

    public var renderOrigin: Vec2 {
        origin
    }

    public var renderSize: Vec2 {
        size
    }

    public var visibleFrame: Rect {
        Rect(
            x: padding.left,
            y: padding.top,
            width: max(size.x - padding.horizontal, 0),
            height: max(size.y - padding.vertical, 0)
        )
    }

    public var visibleBounds: Rect {
        Rect(
            origin: Vec2(
                x: origin.x + padding.left,
                y: origin.y + padding.top
            ),
            size: visibleFrame.size
        )
    }

    public var hasPadding: Bool {
        padding == .zero
    }
}
