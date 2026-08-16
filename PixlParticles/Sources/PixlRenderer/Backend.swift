import Swift

@MainActor
public protocol Backend: AnyObject {
    func renderPoints(
        count: Int,
        positionsChanged: Bool,
        interpolation: Float,
        viewProjection: Matrix4x4,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void
    ) throws
}
