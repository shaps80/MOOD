import Pixl2D

/// A lightweight submission source using logical, top-left screen coordinates.
public struct ScreenSpace {
    package let context: GameContext

    package init(context: GameContext) {
        self.context = context
    }

    /// Submits an analytic shape to the context's normal render queue.
    ///
    /// Axis-aligned centred segment strokes are aligned to physical pixels.
    public func submit(_ shape: Shape, transform: Transform2D) {
        context.renderQueue.submit(
            shape,
            transform: alignedTransform(for: shape, transform: transform)
        )
    }

    private func alignedTransform(for shape: Shape, transform: Transform2D) -> Transform2D {
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

    private func alignedStrokeCenter(_ value: Float, width: Float) -> Float {
        let halfWidth = width * context.displayScale * 0.5
        return ((value * context.displayScale - halfWidth).rounded() + halfWidth)
            / context.displayScale
    }
}

public extension GameContext {
    /// A lightweight source for aligned logical screen-space submissions.
    var screenSpace: ScreenSpace { .init(context: self) }
}
