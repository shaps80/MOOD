import Pixl2D
import PixlFoundation
import PixlPlatform

extension SpriteSubmission {
    init(sprite: Sprite, transform: Transform2D) {
        let width = sprite.region.source.size.x
            * (sprite.isFlipped ? -1 : 1)
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
            sampler: SamplerDescriptor(
                minFilter: sprite.material.filtering.minification.platform,
                magFilter: sprite.material.filtering.magnification.platform,
                addressModeU: sprite.material.addressing.horizontal.platform,
                addressModeV: sprite.material.addressing.vertical.platform
            ),
            blendMode: sprite.material.blendMode.platform,
            layer: sprite.layer.rawValue,
            order: sprite.order
        )
    }
}

private extension Sprite.Material.Filter {
    var platform: SamplerFilter {
        switch self {
        case .nearest: .nearest
        case .linear: .linear
        }
    }
}

private extension Sprite.Material.AddressMode {
    var platform: SamplerAddressMode {
        switch self {
        case .clampToEdge: .clampToEdge
        case .repeat: .repeat
        case .mirrorRepeat: .mirrorRepeat
        }
    }
}

private extension Sprite.Material.BlendMode {
    var platform: BlendMode {
        switch self {
        case .normal: .normal
        case .replace: .replace
        }
    }
}
