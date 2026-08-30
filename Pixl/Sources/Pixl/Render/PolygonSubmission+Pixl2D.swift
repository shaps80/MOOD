import Pixl2D
import PixlFoundation
import PixlGraphics
import PixlPlatform

extension PolygonSubmission {
    init(
        polygon: Polygon,
        geometry: UInt32,
        transform: Transform2D,
        rendering: RenderProperties = .init(),
        material: Pixl2D.Material = .unlit
    ) {
        _ = material
        #warning("Polygon gradient and texture paints currently use temporary solid-colour fallbacks")
        let color: PixlGraphics.Color
        switch polygon.paint {
        case .color(let value):
            color = value
        case .gradient(let value):
            color = value.gradient.stops[0].color
        case .texture:
            color = .gray
        }

        let bounds = transform.transformed(bounds: polygon.bounds)
        self.init(
            boundsMinimum: bounds.origin,
            boundsMaximum: bounds.origin + bounds.size,
            geometry: geometry,
            transformX: .init(transform.x.x, transform.x.y),
            transformY: .init(transform.y.x, transform.y.y),
            transformTranslation: .init(
                transform.translation.x,
                transform.translation.y
            ),
            color: color.premultiplied,
            blendMode: rendering.blendMode.platform,
            layer: rendering.layer.rawValue,
            order: rendering.order
        )
    }
}

private extension PixlGraphics.Color {
    var premultiplied: SIMD4<Float> {
        .init(red * opacity, green * opacity, blue * opacity, opacity)
    }
}

private extension RenderProperties.BlendMode {
    var platform: BlendMode {
        switch self {
        case .normal: .premultiplied
        case .replace: .replace
        }
    }
}
