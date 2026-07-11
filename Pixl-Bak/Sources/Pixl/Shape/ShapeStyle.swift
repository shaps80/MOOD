import Swift

public protocol ShapeStyle: Sendable {
    func resolve() -> Color
}

public extension ShapeStyle where Self == Color {
    static var clear: Self { .clear }
    static var white: Self { .white }
    static var gray: Self { .gray }
    static var black: Self { .black }
    static var red: Self { .red }
    static var yellow: Self { .yellow }
    static var green: Self { .green }
    static var blue: Self { .blue }
}

extension Color: ShapeStyle {
    public func resolve() -> Color {
        self
    }
}

public struct FillStyle: Equatable, Sendable {
    public var antialiased: Bool

    public init(antialiased: Bool = true) {
        self.antialiased = antialiased
    }
}

public enum RoundedCornerStyle: Equatable, Sendable {
    case circular
    case continuous
}

public enum LineCap: Equatable, Sendable {
    case butt
    case square
    case round
}

public struct StrokeStyle: Equatable, Sendable {
    public var lineWidth: Double
    public var lineCap: LineCap
    public var antialiased: Bool

    public init(
        lineWidth: Double = 1,
        lineCap: LineCap = .butt,
        antialiased: Bool = true
    ) {
        self.lineWidth = lineWidth
        self.lineCap = lineCap
        self.antialiased = antialiased
    }
}
