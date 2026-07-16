import Swift

public typealias Color = SIMD4<Float>

public extension Color {
    init(red: Float, green: Float, blue: Float, opacity: Float = 1) {
        self = [red, green, blue, opacity]
    }

    static let white: Self = .init(red: 1, green: 1, blue: 1)
    static let black: Self = .init(red: 0, green: 0, blue: 0)
    static let clear: Self = .init(red: 1, green: 1, blue: 1, opacity: 0)
}
