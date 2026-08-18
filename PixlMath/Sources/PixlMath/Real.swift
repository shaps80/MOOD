import PixlMathC
import Swift

public protocol Real: BinaryFloatingPoint, Sendable {
    static func exp(_ value: Self) -> Self
}

extension Float: Real {
    @inlinable @inline(__always)
    public static func exp(_ value: Float) -> Float {
        pixl_expf(value)
    }
}

extension Double: Real {
    @inlinable @inline(__always)
    public static func exp(_ value: Double) -> Double {
        pixl_exp(value)
    }
}
