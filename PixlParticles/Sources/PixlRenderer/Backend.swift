import Swift

@MainActor
public protocol Backend: AnyObject {
    func renderPoints(
        count: Int,
        positionsChanged: Bool,
        idsChanged: Bool,
        interpolation: Float,
        viewProjection: Matrix4x4,
        viewport: ViewportSize,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void,
        writeIDs: (UnsafeMutableBufferPointer<UInt64>) -> Void
    ) throws
}
