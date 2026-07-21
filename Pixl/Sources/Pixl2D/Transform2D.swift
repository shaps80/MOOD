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

    /// Creates a transform from decomposed position, rotation, and scale.
    ///
    /// Omitting every argument creates the identity transform. Supplying only
    /// the first argument creates a translation, such as `Transform2D(position)`.
    ///
    /// - Parameters:
    ///   - translation: World-space position.
    ///   - rotation: Counter-clockwise rotation in radians.
    ///   - scale: Local-axis scale.
    public init(
        _ translation: Vec2 = .zero,
        rotation: Float = 0,
        scale: Vec2 = .one
    ) {
        let rotation = sinCos(rotation)
        let cosine = Float(rotation.cosine)
        let sine = Float(rotation.sine)
        let scaleX = Float(scale.x)
        let scaleY = Float(scale.y)

        x = .init(cosine * scaleX, sine * scaleX, 0)
        y = .init(-sine * scaleY, cosine * scaleY, 0)
        self.translation = .init(
            Float(translation.x),
            Float(translation.y),
            1
        )
    }

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
    /// - Returns: A copy with the rotation composed after this transform.
    public func rotated(by radians: Float) -> Self {
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
    ///
    /// - Parameters:
    ///   - x: Scale along the local x axis.
    ///   - y: Scale along the local y axis.
    /// - Returns: A copy with the scale composed after this transform.
    public func scaled(x: Float, y: Float) -> Self {
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
    /// - Returns: A copy translated by `offset` relative to this transform's axes.
    public func translated(by offset: Vec2) -> Self {
        let xOffset = Float(offset.x)
        let yOffset = Float(offset.y)
        return .init(
            x: x,
            y: y,
            translation: translation + (x * xOffset) + (y * yOffset)
        )
    }

    public func translated(x: Float, y: Float) -> Self {
        translated(by: .init(x, y))
    }
}

extension Transform2D {
    public static let identity: Self = .init(
        .zero,
        rotation: .zero,
        scale: .one
    )
}
