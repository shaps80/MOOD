import Pixl2D
import PixlFoundation
import PixlGraphics

extension PrimitiveSubmission {
    init(
        shape: PrimitiveShape,
        transform: Transform2D,
        style: PrimitiveShape.Style,
        layer: RenderLayer,
        order: UInt32
    ) {
        let rect: Rect
        let geometry: PrimitiveGeometry
        switch shape {
        case .rect(let value):
            rect = value
            geometry = .rect
        case .ellipse(let value):
            rect = value
            geometry = .ellipse
        }
        precondition(rect.isValid && rect.size.x > 0 && rect.size.y > 0)

        let kind: PrimitiveKind
        let color: SIMD4<Float>
        let width: Float
        switch style {
        case .fill(let value):
            kind = geometry == .rect ? .rectFill : .ellipseFill
            color = value.premultiplied
            width = 0
        case .stroke(let value, let valueWidth):
            precondition(valueWidth.isFinite && valueWidth > 0)
            kind = geometry == .rect ? .rectStroke : .ellipseStroke
            color = value.premultiplied
            width = valueWidth
        }

        let transformX = SIMD2(transform.x.x, transform.x.y)
        let transformY = SIMD2(transform.y.x, transform.y.y)
        let translation = SIMD2(transform.translation.x, transform.translation.y)
        let center = rect.center
        let halfSize = rect.size * 0.5
        let worldCenter = transformX * center.x + transformY * center.y + translation
        let extent = SIMD2<Float>(
            abs(transformX.x) * halfSize.x + abs(transformY.x) * halfSize.y,
            abs(transformX.y) * halfSize.x + abs(transformY.y) * halfSize.y
        )

        self.init(
            boundsMinimum: worldCenter - extent,
            boundsMaximum: worldCenter + extent,
            transformX: transformX,
            transformY: transformY,
            transformTranslation: translation,
            origin: rect.origin,
            size: rect.size,
            color: color,
            width: width,
            kind: kind,
            layer: layer.rawValue,
            order: order
        )
    }
}

private enum PrimitiveGeometry {
    case rect
    case ellipse
}

private extension Color {
    var premultiplied: SIMD4<Float> {
        .init(red * opacity, green * opacity, blue * opacity, opacity)
    }
}
