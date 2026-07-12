import PixlMathC
import Swift

public struct SinCos<Scalar: Sendable>: Sendable {
    public let sine: Scalar
    public let cosine: Scalar

    public init(sine: Scalar, cosine: Scalar) {
        self.sine = sine
        self.cosine = cosine
    }
}

public func sin(_ radians: Float) -> Float {
    pixl_sinf(radians)
}

public func cos(_ radians: Float) -> Float {
    pixl_cosf(radians)
}

public func sinCos(_ radians: Float) -> SinCos<Float> {
    let value = pixl_sin_cosf(radians)
    return .init(sine: value.sine, cosine: value.cosine)
}

public func sin(_ radians: Double) -> Double {
    pixl_sin(radians)
}

public func cos(_ radians: Double) -> Double {
    pixl_cos(radians)
}

public func sinCos(_ radians: Double) -> SinCos<Double> {
    let value = pixl_sin_cos(radians)
    return .init(sine: value.sine, cosine: value.cosine)
}
