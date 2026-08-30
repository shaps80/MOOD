import PixlPlatform
import PixlFoundation
import PixlGraphics
import Pixl2D

extension SpriteSubmission {
    init(
        sprite: Sprite,
        transform: Transform2D,
        rendering: RenderProperties = .init(),
        material: Pixl2D.Material = .unlit
    ) {
        _ = material
        let width = sprite.region.source.size.x
        let height = sprite.region.source.size.y
        let transform = transform.scaled(x: width, y: height)
        let textureCoordinates = sprite.region.textureCoordinates
        let transformX = SIMD2(transform.x.x, transform.x.y)
        let transformY = SIMD2(transform.y.x, transform.y.y)
        let translation = SIMD2(
            transform.translation.x,
            transform.translation.y
        )
        let extent = SIMD2<Float>(
            abs(transformX.x) + abs(transformY.x),
            abs(transformX.y) + abs(transformY.y)
        ) * 0.5

        self.init(
            boundsMinimum: translation - extent,
            boundsMaximum: translation + extent,
            texture: TextureResourceID(rawValue: sprite.asset.identity),
            textureCoordinateOrigin: textureCoordinates.origin,
            textureCoordinateScale: textureCoordinates.scale,
            transformX: transformX,
            transformY: transformY,
            transformTranslation: translation,
            tintRGBA8: sprite.modulation.rgba8,
            modulationMode: sprite.modulationMode.rawValue
                | (sprite.asset.alpha == .premultiplied ? 2 : 0),
            sampler: SamplerDescriptor(
                minFilter: sprite.sampling.filtering.minification.platform,
                magFilter: sprite.sampling.filtering.magnification.platform,
                addressModeU: sprite.sampling.addressing.horizontal.platform,
                addressModeV: sprite.sampling.addressing.vertical.platform
            ),
            blendMode: rendering.blendMode.platform(
                alpha: sprite.asset.alpha
            ),
            layer: rendering.layer.rawValue,
            order: rendering.order
        )
    }
}

private extension PixlGraphics.Color {
    var rgba8: UInt32 {
        func channel(_ value: Float) -> UInt32 {
            UInt32((Swift.min(Swift.max(value, 0), 1) * 255).rounded())
        }
        return channel(red)
            | channel(green) << 8
            | channel(blue) << 16
            | channel(opacity) << 24
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

private extension RenderProperties.BlendMode {
    func platform(alpha: TextureAlpha) -> BlendMode {
        switch self {
        case .normal:
            alpha == .premultiplied ? .premultiplied : .normal
        case .replace: .replace
        }
    }
}
