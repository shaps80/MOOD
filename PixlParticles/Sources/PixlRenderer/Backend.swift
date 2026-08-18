import Swift

public protocol Backend: AnyObject {
    func renderPoints(
        count: Int,
        positionsChanged: Bool,
        colorsChanged: Bool,
        idsChanged: Bool,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        viewProjection: Matrix4x4,
        viewport: ViewportSize,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void,
        writeIDs: (UnsafeMutableBufferPointer<UInt64>) -> Void,
        writePreviousColors: (UnsafeMutableRawBufferPointer) -> Void,
        writeCurrentColors: (UnsafeMutableRawBufferPointer) -> Void
    ) throws
}
