import PixlMath
import Swift

public struct Transform2D: BitwiseCopyable, Sendable {
    public let x: SIMD3<Float>
    public let y: SIMD3<Float>
    public let translation: SIMD3<Float>

    public init(
        x: SIMD3<Float>,
        y: SIMD3<Float>,
        translation: SIMD3<Float>
    ) {
        self.x = x
        self.y = y
        self.translation = translation
    }

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
}
