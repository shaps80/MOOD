import Pixl2D
import PixlFoundation
import PixlGraphics
import PixlPlatform
import Testing
@testable import Pixl

@Suite("Sprite submission lowering")
struct SpriteSubmissionTests {
    @Test
    func circleUsesItsRadiusForBothLocalAxes() {
        let submission = ShapeSubmission(
            shape: Shape(.circle(radius: 20)).stroke(.green, width: 2),
            transform: identity
        )

        #expect(submission.parameters.x == 20)
        #expect(submission.parameters.y == 20)
        #expect(submission.parameters.w == 0)
        #expect(submission.quadHalfExtent == SIMD2(21, 21))
    }

    @Test
    func roundingExpandsTheAnalyticBoundaryAndConservativeQuad() {
        let submission = ShapeSubmission(
            shape: Shape(.hexagon).rounding(0.25),
            transform: identity
        )

        #expect(submission.rounding == 0.25)
        #expect(submission.quadHalfExtent == SIMD2(repeating: 0.75))
    }

    @Test
    func regularPolygonRadiiLowerToFormulaApothems() {
        let pentagon = ShapeSubmission(shape: Shape(.pentagon(radius: 2)), transform: identity)
        let hexagon = ShapeSubmission(shape: Shape(.hexagon(radius: 2)), transform: identity)
        let octagon = ShapeSubmission(shape: Shape(.octagon(radius: 2)), transform: identity)

        #expect(abs(pentagon.parameters.x - 2 * 0.809016994) < 0.000_001)
        #expect(abs(hexagon.parameters.x - 2 * 0.866025404) < 0.000_001)
        #expect(abs(octagon.parameters.x - 2 * 0.923879533) < 0.000_001)
        #expect(pentagon.quadHalfExtent == SIMD2(repeating: 2))
        #expect(hexagon.quadHalfExtent == SIMD2(repeating: 2))
        #expect(octagon.quadHalfExtent == SIMD2(repeating: 2))
    }

    @Test
    func heartWidthProducesTightCenteredAnalyticBounds() {
        let submission = ShapeSubmission(shape: Shape(.heart(width: 2)), transform: identity)

        #expect(abs(submission.parameters.x - 1.656854249) < 0.000_001)
        #expect(abs(submission.quadHalfExtent.x - 1) < 0.000_001)
        #expect(abs(submission.quadHalfExtent.y - 0.914213562) < 0.000_001)
        #expect(submission.transformTranslation.y == 0)
    }

    @Test
    func finiteCurvesPassTheirWindowsToTheDistanceFunction() {
        let parabola = ShapeSubmission(
            shape: Shape(.parabola(curvature: 2, size: .init(4, 6))),
            transform: identity
        )
        let hyperbola = ShapeSubmission(
            shape: Shape(.hyperbola(scale: 0.5, size: .init(8, 10))),
            transform: identity
        )

        #expect(parabola.parameters == SIMD4(2, 2, 3, 0))
        #expect(hyperbola.parameters == SIMD4(0.5, 4, 5, 0))
    }

    @Test
    func pointDefinedShapesLowerWithoutChangingCompactABIs() {
        let triangle = ShapeSubmission(shape: Shape(.triangle), transform: identity)
        let bezier = ShapeSubmission(shape: Shape(.quadraticBezier), transform: identity)

        #expect(triangle.kind == .triangle)
        #expect(SIMD2(triangle.extendedParameters.x, triangle.extendedParameters.y) == SIMD2(0.5, -0.5))
        #expect(bezier.kind == .quadraticBezier)
        #expect(SIMD2(bezier.extendedParameters.x, bezier.extendedParameters.y) == SIMD2(0.5, -0.5))
        #expect(MemoryLayout<RenderQueue.Instance>.stride == 48)
        #expect(MemoryLayout<RenderQueue.ShapeInstance>.stride == 96)
        #expect(MemoryLayout<RenderQueue.ExtendedShapeInstance>.stride == 112)
    }

    @Test
    func gradientRowsAreDeduplicatedAndSeparatedFromSolidBatches() {
        let queue = RenderQueue(settings: .init(capacity: 4))
        let gradient = Gradient(colors: [.red, .blue])
        queue.submit(Shape(.circle).fill(gradient), transform: identity)
        queue.submit(Shape(.rect).fill(gradient), transform: identity)
        queue.submit(Shape(.circle).fill(.green), transform: identity)
        var view = RenderQueue.View(
            projectionX: .init(1, 0, 0), projectionY: .init(0, 1, 0),
            projectionTranslation: .init(0, 0, 1),
            boundsMinimum: .init(repeating: -100), boundsMaximum: .init(repeating: 100)
        )

        withUnsafePointer(to: &view) { pointer in
            queue.execute(views: .init(start: pointer, count: 1)) { execution in
                #expect(execution.gradientCount == 1)
                #expect(execution.gradientAtlas.count == 256 * 4)
                #expect(execution.shapeMaterials.contains { $0.usesGradient })
                #expect(execution.shapeMaterials.contains { !$0.usesGradient })
            }
        }
    }

    @Test
    func gradientPlacementsLowerToCompactShapeParameters() {
        let gradient = Gradient(colors: [.red, .blue])
        let linear = ShapeSubmission(
            shape: Shape(.circle).fill(gradient, from: .init(-1, 0), to: .init(1, 0)),
            transform: identity,
            gradientSlot: 3
        )
        let radial = ShapeSubmission(
            shape: Shape(.circle).fill(gradient, center: .init(1, 2), radius: 4),
            transform: identity,
            gradientSlot: 3
        )
        let angular = ShapeSubmission(
            shape: Shape(.circle).fill(gradient, center: .init(1, 2), angle: .degrees(90)),
            transform: identity,
            gradientSlot: 3
        )

        #expect(linear.gradientPlacement == 0)
        #expect(linear.gradientLine == SIMD4(-1, 0, 1, 0))
        #expect(radial.gradientPlacement == 1)
        #expect(radial.gradientLine == SIMD4(1, 2, 4, 0))
        #expect(angular.gradientPlacement == 2)
        #expect(angular.gradientLine.x == 1)
        #expect(angular.gradientLine.y == 2)
        #expect(abs(angular.gradientLine.z - .pi / 2) < 0.0001)
    }

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
