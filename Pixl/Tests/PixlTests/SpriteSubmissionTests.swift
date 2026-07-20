import Pixl2D
import PixlFoundation
import PixlGraphics
import PixlPlatform
import Testing
@testable import Pixl

@Suite("Sprite submission lowering")
struct SpriteSubmissionTests {
    @Test
    func lowersEverySpritePropertyIntoPrimitiveExecutionData() {
        let asset = TextureAsset(identity: 42, size: SIMD2(8, 4))
        let region = TextureRegion(
            asset: asset,
            source: Rect(x: 2, y: 1, width: 4, height: 2)
        )
        let sprite = Sprite(
            region: region,
            material: Sprite.Material(
                filtering: .init(
                    minification: .linear,
                    magnification: .nearest
                ),
                addressing: .init(
                    horizontal: .repeat,
                    vertical: .mirrorRepeat
                ),
                blendMode: .replace
            ),
            layer: 7,
            order: 9,
            isFlipped: true
        )

        let submission = SpriteSubmission(
            sprite: sprite,
            transform: identity
        )

        #expect(submission.texture.rawValue == 42)
        #expect(submission.textureCoordinateOrigin == SIMD2(0.25, 0.25))
        #expect(submission.textureCoordinateScale == SIMD2(0.5, 0.5))
        #expect(submission.boundsMinimum == SIMD2(-2, -1))
        #expect(submission.boundsMaximum == SIMD2(2, 1))
        #expect(submission.transformX == SIMD2(-4, 0))
        #expect(submission.transformY == SIMD2(0, 2))
        #expect(submission.transformTranslation == SIMD2(0, 0))
        #expect(submission.sampler.minFilter == .linear)
        #expect(submission.sampler.magFilter == .nearest)
        #expect(submission.sampler.mipFilter == .nearest)
        #expect(submission.sampler.addressModeU == .repeat)
        #expect(submission.sampler.addressModeV == .mirrorRepeat)
        #expect(submission.sampler.addressModeW == .clampToEdge)
        #expect(submission.blendMode == .replace)
        #expect(submission.layer == 7)
        #expect(submission.order == 9)
    }

    @Test
    func laterSpriteMutationDoesNotAlterAnEarlierSnapshot() {
        let asset = TextureAsset(identity: 1, size: SIMD2(2, 2))
        var sprite = Sprite(region: TextureRegion(asset: asset))
        let first = SpriteSubmission(sprite: sprite, transform: identity)

        sprite.layer = 100
        sprite.isFlipped = true
        sprite.material.filtering = .linear
        sprite.material.addressing = .repeat
        sprite.material.blendMode = .replace
        let second = SpriteSubmission(sprite: sprite, transform: identity)

        #expect(first.transformX == SIMD2(2, 0))
        #expect(first.sampler.minFilter == .nearest)
        #expect(first.sampler.addressModeU == .clampToEdge)
        #expect(first.blendMode == .normal)

        #expect(second.transformX == SIMD2(-2, 0))
        #expect(second.sampler.minFilter == .linear)
        #expect(second.sampler.addressModeU == .repeat)
        #expect(second.blendMode == .replace)
    }

    @Test
    func normalCompositionMatchesTextureAlphaProcessing() {
        let premultiplied = TextureAsset(
            identity: 1,
            size: SIMD2(1, 1),
            alpha: .premultiplied
        )
        let passthrough = TextureAsset(
            identity: 2,
            size: SIMD2(1, 1),
            alpha: .passthrough
        )

        let premultipliedSubmission = SpriteSubmission(
            sprite: Sprite(region: TextureRegion(asset: premultiplied)),
            transform: identity
        )
        let passthroughSubmission = SpriteSubmission(
            sprite: Sprite(region: TextureRegion(asset: passthrough)),
            transform: identity
        )

        #expect(premultipliedSubmission.blendMode == .premultiplied)
        #expect(passthroughSubmission.blendMode == .normal)
    }

    private var identity: Transform2D {
        Transform2D(
            x: SIMD3(1, 0, 0),
            y: SIMD3(0, 1, 0),
            translation: SIMD3(0, 0, 1)
        )
    }
}
