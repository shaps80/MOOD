import Swift

public struct Color: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public extension Color {
    static let white: Self = .init(
        red: 1,
        green: 1,
        blue: 1,
        alpha: 1
    )

    static let gray: Self = .init(
        red: 0.5,
        green: 0.5,
        blue: 0.5,
        alpha: 1
    )

    static let black: Self = .init(
        red: 0,
        green: 0,
        blue: 0,
        alpha: 1
    )

    static let red: Self = .init(
        red: 1,
        green: 0,
        blue: 0,
        alpha: 1
    )

    static let green: Self = .init(
        red: 0,
        green: 1,
        blue: 0,
        alpha: 1
    )

    static let blue: Self = .init(
        red: 0,
        green: 0,
        blue: 1,
        alpha: 1
    )
}
