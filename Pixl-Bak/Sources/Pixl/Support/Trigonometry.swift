import Swift

/// Returns the sine of an angle.
///
/// ```swift
/// let y = sin(.degrees(90))
/// ```
public func sin(_ angle: Angle) -> Double {
    sinRadians(angle.radians)
}

/// Returns the cosine of an angle.
///
/// ```swift
/// let x = cos(.degrees(0))
/// ```
public func cos(_ angle: Angle) -> Double {
    cosRadians(angle.radians)
}

/// Returns the sine and cosine of an angle.
///
/// Use this when both values are needed from the same angle.
///
/// ```swift
/// let rotation = sincos(.degrees(45))
/// ```
public func sincos(_ angle: Angle) -> (sin: Double, cos: Double) {
    (
        sin: sinRadians(angle.radians),
        cos: cosRadians(angle.radians)
    )
}

private let halfPi = Double.pi / 2
private let twoPi = Double.pi * 2

private func sinRadians(_ radians: Double) -> Double {
    let x = foldToHalfPi(normalize(radians))
    let x2 = x * x

    return x * (
        1
        + x2 * (
            -1.0 / 6.0
            + x2 * (
                1.0 / 120.0
                + x2 * (
                    -1.0 / 5_040.0
                    + x2 * (
                        1.0 / 362_880.0
                        + x2 * (-1.0 / 39_916_800.0)
                    )
                )
            )
        )
    )
}

private func cosRadians(_ radians: Double) -> Double {
    var x = normalize(radians)
    var sign = 1.0

    if x > halfPi {
        x = Double.pi - x
        sign = -1
    } else if x < -halfPi {
        x = -Double.pi - x
        sign = -1
    }

    let x2 = x * x

    return sign * (
        1
        + x2 * (
            -1.0 / 2.0
            + x2 * (
                1.0 / 24.0
                + x2 * (
                    -1.0 / 720.0
                    + x2 * (
                        1.0 / 40_320.0
                        + x2 * (-1.0 / 3_628_800.0)
                    )
                )
            )
        )
    )
}

private func normalize(_ radians: Double) -> Double {
    var x = radians - ((radians / twoPi).rounded(.toNearestOrAwayFromZero) * twoPi)

    if x > Double.pi {
        x -= twoPi
    } else if x < -Double.pi {
        x += twoPi
    }

    return x
}

private func foldToHalfPi(_ radians: Double) -> Double {
    if radians > halfPi {
        return Double.pi - radians
    }

    if radians < -halfPi {
        return -Double.pi - radians
    }

    return radians
}
