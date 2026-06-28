import Swift

public protocol Shape: Sendable {
    func path(in rect: Rect) -> Path
}

extension Path: Shape {
    public func path(in rect: Rect) -> Path {
        self
    }
}

public struct Rectangle: Shape, Equatable, Sendable {
    public init() {}

    public func path(in rect: Rect) -> Path {
        Path(rect)
    }
}

extension Shape where Self == Rectangle {
    static var rect: Self { .init() }
}

public struct RoundedRectangle: Shape, Equatable, Sendable {
    public var cornerRadius: Double
    public var style: RoundedCornerStyle

    public init(
        cornerRadius: Double,
        style: RoundedCornerStyle = .continuous
    ) {
        self.cornerRadius = cornerRadius
        self.style = style
    }

    public func path(in rect: Rect) -> Path {
        Path(roundedRect: rect, cornerRadius: cornerRadius, style: style)
    }
}

extension Shape where Self == RoundedRectangle {
    public static func rect(cornerRadius: Double, style: RoundedCornerStyle = .continuous) -> Self {
        .init(cornerRadius: cornerRadius, style: style)
    }
}

public struct Ellipse: Shape, Equatable, Sendable {
    public init() {}

    public func path(in rect: Rect) -> Path {
        Path(ellipseIn: rect)
    }
}

extension Shape where Self == Ellipse {
    public static var ellipse: Self { .init() }
}

public struct Circle: Shape, Equatable, Sendable {
    public init() {}

    public func path(in rect: Rect) -> Path {
        Path(ellipseIn: rect)
    }
}

extension Shape where Self == Circle {
    public static var circle: Self { .init() }
}

public struct Capsule: Shape, Equatable, Sendable {
    internal var style: RoundedCornerStyle

    public init(style: RoundedCornerStyle = .continuous) {
        self.style = style
    }

    public func path(in rect: Rect) -> Path {
        Path(
            roundedRect: rect,
            cornerRadius: min(rect.size.x, rect.size.y) / 2,
            style: style
        )
    }
}

extension Shape where Self == Capsule {
    public static func capsule(style: RoundedCornerStyle) -> Self {
        .init(style: style)
    }
}
