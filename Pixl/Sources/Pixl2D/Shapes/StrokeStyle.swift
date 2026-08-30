import PixlGraphics

/// Analytic boundary stroke.
public struct StrokeStyle: Hashable, Sendable {
    public var color: Color
    public var width: Float
    public var alignment: Alignment

    public init(
        _ color: Color,
        width: Float,
        alignment: Alignment = .center
    ) {
        precondition(width.isFinite && width > 0)
        self.color = color
        self.width = width
        self.alignment = alignment
    }
}

public extension StrokeStyle {
    enum Alignment: Hashable, Sendable {
        case center
        case inside
        case outside
    }
}
