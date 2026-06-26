import Swift

public struct EdgeInsets: Equatable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double, left: Double, bottom: Double, right: Double) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public init(horizontal: Double, vertical: Double) {
        self.init(
            top: vertical,
            left: horizontal,
            bottom: vertical,
            right: horizontal
        )
    }

    public init(all amount: Double) {
        self.init(
            top: amount,
            left: amount,
            bottom: amount,
            right: amount
        )
    }

    public static let zero = EdgeInsets(all: 0)

    public var horizontal: Double {
        left + right
    }

    public var vertical: Double {
        top + bottom
    }
}
