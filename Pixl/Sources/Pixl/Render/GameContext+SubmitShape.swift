import Pixl2D
import PixlMath

public extension GameContext {
    /// Submits an analytic shape in logical screen space.
    ///
    /// Axis-aligned centred segment strokes are aligned in physical-pixel
    /// space before entering the normal render queue. Layer, order, and
    /// submission ordering are otherwise unchanged.
    func submit(
        _ shape: Shape,
        transform: Transform2D,
        in coordinateSpace: ScreenCoordinateSpace
    ) {
        renderQueue.submit(
            shape,
            transform: alignedScreenTransform(for: shape, transform: transform)
        )
    }
}

private extension GameContext {
    func alignedScreenTransform(for shape: Shape, transform: Transform2D) -> Transform2D {
        guard
            case .segment(let segment) = shape.geometry,
            shape.strokeColor != nil,
            shape.strokeWidth > 0,
            shape.strokeAlignment == .center
        else { return transform }

        let start = transform.translation
            + transform.x * Float(segment.start.x)
            + transform.y * Float(segment.start.y)
        let end = transform.translation
            + transform.x * Float(segment.end.x)
            + transform.y * Float(segment.end.y)
        let delta = end - start
        let epsilon: Float = 0.0001
        var offset = SIMD3<Float>.zero

        if abs(delta.x) <= epsilon {
            let width = shape.strokeWidth
                * (transform.x.x * transform.x.x + transform.x.y * transform.x.y).squareRoot()
            offset.x = alignedStrokeCenter(start.x, width: width) - start.x
        } else if abs(delta.y) <= epsilon {
            let width = shape.strokeWidth
                * (transform.y.x * transform.y.x + transform.y.y * transform.y.y).squareRoot()
            offset.y = alignedStrokeCenter(start.y, width: width) - start.y
        }

        return .init(
            x: transform.x,
            y: transform.y,
            translation: transform.translation + offset
        )
    }

    func alignedStrokeCenter(_ value: Float, width: Float) -> Float {
        let halfWidth = width * displayScale * 0.5
        return ((value * displayScale - halfWidth).rounded() + halfWidth) / displayScale
    }
}
