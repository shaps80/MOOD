import Swift
import Foundation

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

    public func rotated(by radians: Float) -> Self {
        let cosine = cos(radians)
        let sine = sin(radians)
        let rotatedX = (x * cosine) + (y * sine)
        let rotatedY = (x * -sine) + (y * cosine)

        return .init(
            x: rotatedX,
            y: rotatedY,
            translation: translation
        )
    }
}
