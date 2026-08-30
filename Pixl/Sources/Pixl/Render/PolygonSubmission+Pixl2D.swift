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
        material: Pixl2D.Material = .unlit,
        gradientSlot: UInt32 = .max
    ) {
        _ = material
        let paintKind: PolygonPaintKind
        let paintParameters: SIMD4<Float>
        let color: PixlGraphics.Color
        let gradientPlacement: UInt32
        let texture: TextureResourceID?
        let sampler: SamplerDescriptor
        let blendMode: BlendMode
        switch polygon.paint {
        case .color(let value):
            paintKind = .color
            paintParameters = .zero
            color = value
            gradientPlacement = 0
            texture = nil
            sampler = .init()
            blendMode = rendering.blendMode.platform
        case .gradient(let fill):
            paintKind = .gradient
            color = .clear
            texture = nil
            sampler = .init()
            blendMode = rendering.blendMode.platform
            switch fill.placement {
            case .linear(let start, let end):
                paintParameters = .init(start.x, start.y, end.x, end.y)
                gradientPlacement = 0
            case .radial(let center, let radius):
                paintParameters = .init(center.x, center.y, radius, 0)
                gradientPlacement = 1
            case .angular(let center, let angle):
                paintParameters = .init(center.x, center.y, angle.radians, 0)
                gradientPlacement = 2
            }
        case .texture(let value):
            let coordinates = value.region.textureCoordinates
            paintKind = .texture
            paintParameters = .init(
                coordinates.origin.x,
                coordinates.origin.y,
                coordinates.scale.x,
                coordinates.scale.y
            )
            color = .clear
            gradientPlacement = 0
            texture = TextureResourceID(rawValue: value.region.asset.identity)
            sampler = SamplerDescriptor(
                minFilter: value.sampling.filtering.minification.platform,
                magFilter: value.sampling.filtering.magnification.platform,
                addressModeU: value.sampling.addressing.horizontal.platform,
                addressModeV: value.sampling.addressing.vertical.platform
            )
            blendMode = rendering.blendMode.platform(alpha: value.region.asset.alpha)
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
            paintKind: paintKind,
            paintParameters: paintParameters,
            color: color.premultiplied,
            gradientSlot: gradientSlot,
            gradientPlacement: gradientPlacement,
            texture: texture,
            sampler: sampler,
            blendMode: blendMode,
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

    func platform(alpha: TextureAlpha) -> BlendMode {
        switch self {
        case .normal:
            alpha == .premultiplied ? .premultiplied : .normal
        case .replace: .replace
        }
    }
}

private extension TextureSampling.Filter {
    var platform: SamplerFilter {
        switch self {
        case .nearest: .nearest
        case .linear: .linear
        }
    }
}

private extension TextureSampling.AddressMode {
    var platform: SamplerAddressMode {
        switch self {
        case .clampToEdge: .clampToEdge
        case .repeat: .repeat
        case .mirrorRepeat: .mirrorRepeat
        }
    }
}
