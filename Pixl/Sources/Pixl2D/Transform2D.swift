import PixlMath
import Swift

/// A column-major 2D affine transform suitable for GPU vertex bytes.
public struct Transform2D: BitwiseCopyable, Sendable {
    /// First homogeneous matrix column.
    public let x: SIMD3<Float>

    /// Second homogeneous matrix column.
    public let y: SIMD3<Float>

    /// Translation homogeneous matrix column.
    public let translation: SIMD3<Float>

    /// Creates a column-major 2D affine transform.
    ///
    /// - Parameters:
    ///   - x: First homogeneous matrix column.
    ///   - y: Second homogeneous matrix column.
    ///   - translation: Translation homogeneous matrix column.
    public init(
        x: SIMD3<Float>,
        y: SIMD3<Float>,
        translation: SIMD3<Float>
    ) {
        self.x = x
        self.y = y
        self.translation = translation
    }

    /// Returns this transform followed by a counter-clockwise rotation.
    ///
    /// - Parameter radians: Rotation angle in radians. Use `.pi / 2` for a
    ///   quarter turn counter-clockwise.
    public func rotated(by radians: Double) -> Self {
        let rotation = sinCos(radians)
        let cosine = Float(rotation.cosine)
        let sine = Float(rotation.sine)
        let rotatedX = (x * cosine) + (y * sine)
        let rotatedY = (x * -sine) + (y * cosine)

        return .init(
            x: rotatedX,
            y: rotatedY,
            translation: translation
        )
    }

    /// Returns this transform followed by a local-space scale.
    ///
    /// Negative values mirror geometry around its local origin. For example,
    /// `scaled(x: -1, y: 1)` flips a sprite horizontally.
    public func scaled(x: Double, y: Double) -> Self {
        .init(
            x: self.x * Float(x),
            y: self.y * Float(y),
            translation: translation
        )
    }

    /// Returns this transform followed by a world-space translation.
    ///
    /// - Parameter offset: World-space displacement applied after the current
    ///   linear transform.
    public func translated(by offset: Vec2) -> Self {
        let xOffset = Float(offset.x)
        let yOffset = Float(offset.y)
        return .init(
            x: x,
            y: y,
            translation: translation + (x * xOffset) + (y * yOffset)
        )
    }
}
