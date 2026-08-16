import Swift

/// Cross-platform deterministic approximations for common trigonometric operations.
///
/// Keep this implementation isolated from particle-system concerns. It is intended to
/// move into PixlMath once that module exists.
///
/// The approximations are ported from Erin Catto's Box3D implementation:
/// https://github.com/erincatto/box3d/blob/main/src/math_functions.c
/// Box3D is licensed under the MIT License.
struct SinCos<Scalar: BinaryFloatingPoint>: Equatable {
    let cosine: Scalar
    let sine: Scalar
}

extension SinCos: Sendable where Scalar: Sendable {}

@inline(__always)
func atan2<Scalar: BinaryFloatingPoint>(y: Scalar, x: Scalar) -> Scalar {
    guard x != 0 || y != 0 else {
        return 0
    }

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

    if absoluteY > absoluteX {
        result = 0.5 * pi - result
    }
    if x < 0 {
        result = pi - result
    }
    if y < 0 {
        result = -result
    }

    return result
}

@inline(__always)
func atan<Scalar: BinaryFloatingPoint>(_ value: Scalar) -> Scalar {
    atan2(y: value, x: 1)
}

@inline(__always)
func sinCos<Scalar: BinaryFloatingPoint>(_ radians: Scalar) -> SinCos<Scalar> {
    let pi: Scalar = 3.141592653589793
    let angle = unwindAngle(radians, pi: pi)
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
        sine = -16 * y * (pi - y) / (5 * piSquared - 4 * y * (pi - y))
    } else {
        sine = 16 * angle * (pi - angle) / (5 * piSquared - 4 * angle * (pi - angle))
    }

    let magnitude = (sine * sine + cosine * cosine).squareRoot()
    let inverseMagnitude: Scalar = magnitude > 0 ? 1 / magnitude : 0
    return SinCos(
        cosine: cosine * inverseMagnitude,
        sine: sine * inverseMagnitude
    )
}

@inline(__always)
func sin<Scalar: BinaryFloatingPoint>(_ radians: Scalar) -> Scalar {
    sinCos(radians).sine
}

@inline(__always)
func cos<Scalar: BinaryFloatingPoint>(_ radians: Scalar) -> Scalar {
    sinCos(radians).cosine
}

@inline(__always)
private func unwindAngle<Scalar: BinaryFloatingPoint>(_ radians: Scalar, pi: Scalar) -> Scalar {
    radians.remainder(dividingBy: 2 * pi)
}
