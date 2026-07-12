import PixlPlatform
import PixlMath

public struct OrthographicCamera: Sendable {
    public var center: Vec2
    public var halfHeight: Double

    public init(center: Vec2 = .zero, halfHeight: Double = 1) {
        precondition(halfHeight > 0)
        self.center = center
        self.halfHeight = halfHeight
    }

    public func projection(for output: RenderTarget) -> Transform2D {
        let size = output.texture.descriptor.size
        precondition(size.width > 0)
        precondition(size.height > 0)

        let halfWidth = halfHeight * Double(size.width) / Double(size.height)
        let xScale = Float(1 / halfWidth)
        let yScale = Float(1 / halfHeight)

        return .init(
            x: .init(xScale, 0, 0),
            y: .init(0, yScale, 0),
            translation: .init(
                Float(-center.x) * xScale,
                Float(-center.y) * yScale,
                1
            )
        )
    }
}
