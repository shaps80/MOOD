import Swift

public protocol Shape: Sendable {
    func path(in rect: Rect) -> Path
}

public struct Rectangle: Shape, Equatable, Sendable {
    public init() {}

    public func path(in rect: Rect) -> Path {
        Path(rect)
    }
}

public struct RoundedRectangle: Shape, Equatable, Sendable {
    public var cornerRadius: Double

    public init(cornerRadius: Double) {
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: Rect) -> Path {
        Path(roundedRect: rect, cornerRadius: cornerRadius)
    }
}

public struct Ellipse: Shape, Equatable, Sendable {
    public init() {}

    public func path(in rect: Rect) -> Path {
        Path(ellipseIn: rect)
    }
}

public struct Circle: Shape, Equatable, Sendable {
    public init() {}

    public func path(in rect: Rect) -> Path {
        Path(ellipseIn: rect)
    }
}

public struct Capsule: Shape, Equatable, Sendable {
    public init() {}

    public func path(in rect: Rect) -> Path {
        Path(
            roundedRect: rect,
            cornerRadius: min(rect.size.x, rect.size.y) / 2
        )
    }
}

public struct StyledShape<Base: Shape>: Shape, Sendable {
    public var base: Base
    public var fill: Path.Fill?
    public var stroke: Path.Stroke?
    public var strokedStyle: StrokeStyle?

    public func path(in rect: Rect) -> Path {
        var path = base.path(in: rect)
        path.fill = fill
        path.stroke = stroke
        path.strokedStyle = strokedStyle
        return path
    }

    public func fill<S: ShapeStyle>(
        _ content: S,
        style: FillStyle = FillStyle()
    ) -> StyledShape<Base> {
        var copy = self

        if let strokedStyle, copy.stroke == nil {
            copy.stroke = .init(color: content.resolve(), style: strokedStyle)
        } else {
            copy.fill = .init(color: content.resolve(), style: style)
        }

        return copy
    }

    public func stroke<S: ShapeStyle>(
        _ content: S,
        style: StrokeStyle
    ) -> StyledShape<Base> {
        var copy = self
        copy.stroke = .init(color: content.resolve(), style: style)
        return copy
    }

    public func stroke<S: ShapeStyle>(
        _ content: S,
        lineWidth: Double = 1
    ) -> StyledShape<Base> {
        stroke(content, style: .init(lineWidth: lineWidth))
    }
}

public extension Shape {
    func fill<S: ShapeStyle>(
        _ content: S,
        style: FillStyle = FillStyle()
    ) -> StyledShape<Self> {
        StyledShape(
            base: self,
            fill: .init(color: content.resolve(), style: style),
            stroke: nil,
            strokedStyle: nil
        )
    }

    func stroke(lineWidth: Double = 1) -> StyledShape<Self> {
        StyledShape(
            base: self,
            fill: nil,
            stroke: nil,
            strokedStyle: .init(lineWidth: lineWidth)
        )
    }

    func stroke<S: ShapeStyle>(
        _ content: S,
        style: StrokeStyle
    ) -> StyledShape<Self> {
        StyledShape(
            base: self,
            fill: nil,
            stroke: .init(color: content.resolve(), style: style),
            strokedStyle: nil
        )
    }

    func stroke<S: ShapeStyle>(
        _ content: S,
        lineWidth: Double = 1
    ) -> StyledShape<Self> {
        stroke(content, style: .init(lineWidth: lineWidth))
    }
}
