import Swift

/// Paired deterministic sine and cosine results.
public struct SinCos<Scalar: Real>: Equatable, Sendable {
    public let sine: Scalar
    public let cosine: Scalar

    @inlinable @inline(__always)
    public init(sine: Scalar, cosine: Scalar) {
        self.sine = sine
        self.cosine = cosine
    }
}

// Deterministic trigonometric approximations ported from Erin Catto's Box3D:
// https://github.com/erincatto/box3d/blob/main/src/math_functions.c
// Box3D is licensed under the MIT License.

@inlinable @inline(__always)
public func atan2<Scalar: Real>(y: Scalar, x: Scalar) -> Scalar {
    guard x != 0 || y != 0 else { return 0 }

    let pi: Scalar = 3.141592653589793
    let absoluteX = abs(x)
    let absoluteY = abs(y)
    let maximum = max(absoluteY, absoluteX)
    let minimum = min(absoluteY, absoluteX)
    let a = minimum / maximum
    let squared = a * a
    let cubed = squared * a
    let fourth = squared * squared
    var result = 0.024840285 * fourth + 0.18681418
    let correction = -0.094097948 * fourth - 0.33213072
    result = result * squared + correction
    result = result * cubed + a

    if absoluteY > absoluteX { result = 0.5 * pi - result }
    if x < 0 { result = pi - result }
    if y < 0 { result = -result }
    return result
}

@inlinable @inline(__always)
public func atan<Scalar: Real>(_ value: Scalar) -> Scalar {
    atan2(y: value, x: 1)
}

@inlinable @inline(__always)
public func sinCos<Scalar: Real>(_ radians: Scalar) -> SinCos<Scalar> {
    let pi: Scalar = 3.141592653589793
    let angle = radians.remainder(dividingBy: 2 * pi)
    let piSquared = pi * pi

    let cosine: Scalar
    if angle < -0.5 * pi {
        let y = angle + pi
        let ySquared = y * y
        cosine = -(piSquared - 4 * ySquared) / (piSquared + ySquared)
    } else if angle > 0.5 * pi {
        let y = angle - pi
        let ySquared = y * y
        cosine = -(piSquared - 4 * ySquared) / (piSquared + ySquared)
    } else {
        let ySquared = angle * angle
        cosine = (piSquared - 4 * ySquared) / (piSquared + ySquared)
    }

    let sine: Scalar
    if angle < 0 {
        let y = angle + pi
        sine = -16 * y * (pi - y)
            / (5 * piSquared - 4 * y * (pi - y))
    } else {
        sine = 16 * angle * (pi - angle)
            / (5 * piSquared - 4 * angle * (pi - angle))
    }

    let magnitude = (sine * sine + cosine * cosine).squareRoot()
    let inverseMagnitude: Scalar = magnitude > 0 ? 1 / magnitude : 0
    return SinCos(
        sine: sine * inverseMagnitude,
        cosine: cosine * inverseMagnitude
    )
}

@inlinable @inline(__always)
public func sin<Scalar: Real>(_ radians: Scalar) -> Scalar {
    sinCos(radians).sine
}

@inlinable @inline(__always)
public func cos<Scalar: Real>(_ radians: Scalar) -> Scalar {
    sinCos(radians).cosine
}

@inlinable @inline(__always)
public func tan<Scalar: Real>(_ radians: Scalar) -> Scalar {
    let value = sinCos(radians)
    return value.sine / value.cosine
}

@inlinable @inline(__always)
public func acos<Scalar: Real>(_ value: Scalar) -> Scalar {
    guard value >= -1, value <= 1 else { return .nan }
    let sine = max(0, 1 - value * value).squareRoot()
    return atan2(y: sine, x: value)
}

@inlinable @inline(__always)
public func exp<Scalar: Real>(_ value: Scalar) -> Scalar {
    Scalar.exp(value)
}
