import Swift

/// Corner radii for a rounded rectangle with uneven corners.
@frozen public struct RectangleCornerRadii: Equatable, Hashable, Sendable, BitwiseCopyable {
    public var topLeading: Float
    public var bottomLeading: Float
    public var bottomTrailing: Float
    public var topTrailing: Float

    public init(
        topLeading: Float = 0,
        bottomLeading: Float = 0,
        bottomTrailing: Float = 0,
        topTrailing: Float = 0
    ) {
        self.topLeading = max(0, topLeading)
        self.bottomLeading = max(0, bottomLeading)
        self.bottomTrailing = max(0, bottomTrailing)
        self.topTrailing = max(0, topTrailing)
    }

    public subscript(corner: Edge.Corner) -> Float {
        switch corner {
        case .topLeading: topLeading
        case .topTrailing: topTrailing
        case .bottomLeading: bottomLeading
        case .bottomTrailing: bottomTrailing
        }
    }

    package func normalized(to size: Size) -> Self {
        let top = topLeading + topTrailing
        let bottom = bottomLeading + bottomTrailing
        let leading = topLeading + bottomLeading
        let trailing = topTrailing + bottomTrailing
        let scale = min(
            1,
            top > 0 ? size.width / top : 1,
            bottom > 0 ? size.width / bottom : 1,
            leading > 0 ? size.height / leading : 1,
            trailing > 0 ? size.height / trailing : 1
        )
        return .init(
            topLeading: topLeading * scale,
            bottomLeading: bottomLeading * scale,
            bottomTrailing: bottomTrailing * scale,
            topTrailing: topTrailing * scale
        )
    }
}
