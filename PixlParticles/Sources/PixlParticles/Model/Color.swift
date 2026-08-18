import Swift

public struct Color: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case red
        case green
        case blue
        case alpha
    }

    public static let white = Color(red: 1, green: 1, blue: 1)

    public let red: Float
    public let green: Float
    public let blue: Float
    public let alpha: Float

    public init(
        red: Float,
        green: Float,
        blue: Float,
        alpha: Float = 1
    ) {
        assert(
            red.isFinite
                && green.isFinite
                && blue.isFinite
                && alpha.isFinite
                && (0...1).contains(alpha),
            "Color components must be finite and alpha must be within 0...1"
        )

        self.red = red.isFinite ? red : 0
        self.green = green.isFinite ? green : 0
        self.blue = blue.isFinite ? blue : 0
        self.alpha = alpha.isFinite ? min(max(alpha, 0), 1) : 0
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try values.decode(Float.self, forKey: .red),
            green: try values.decode(Float.self, forKey: .green),
            blue: try values.decode(Float.self, forKey: .blue),
            alpha: try values.decode(Float.self, forKey: .alpha)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(red, forKey: .red)
        try values.encode(green, forKey: .green)
        try values.encode(blue, forKey: .blue)
        try values.encode(alpha, forKey: .alpha)
    }
}
