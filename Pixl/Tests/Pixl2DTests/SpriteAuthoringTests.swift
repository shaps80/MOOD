import Pixl2D
import PixlGraphics
import Testing

@Suite("Sprite authoring")
struct SpriteAuthoringTests {
    private let asset = TextureAsset(
        identity: 1,
        size: SIMD2(8, 4)
    )

    @Test
    func regionCanCoverAnAssetOrSelectPixels() {
        let full = TextureRegion(asset: asset)
        let selection = TextureRegion(
            asset: asset,
            source: Rect(x: 2, y: 1, width: 4, height: 2)
        )

        #expect(full.source == Rect(x: 0, y: 0, width: 8, height: 4))
        #expect(selection.source == Rect(x: 2, y: 1, width: 4, height: 2))
        #expect(Sprite(region: selection).size == .init(4, 2))
    }

    @Test
    func sheetProducesRowMajorRegionsAndSlices() {
        let sheet = SpriteSheet(asset: asset, columns: 4, rows: 2)

        #expect(sheet.regions.count == 8)
        #expect(sheet.region(column: 2, row: 1).source == Rect(
            x: 4,
            y: 2,
            width: 2,
            height: 2
        ))
        #expect(sheet[row: 1].map(\.source.origin.x) == [0, 2, 4, 6])
        #expect(sheet[column: 1].map(\.source.origin.y) == [0, 2])
    }

    @Test
    func animationTimelineLoopsAndClamps() {
        let frames = SpriteSheet(
            asset: asset,
            columns: 4,
            rows: 1
        ).regions
        var looping = SpriteAnimation.Timeline(
            animation: SpriteAnimation(frames: frames, frameDuration: 1)
        )
        var oneShot = SpriteAnimation.Timeline(
            animation: SpriteAnimation(
                frames: frames,
                frameDuration: 1,
                loops: false
            )
        )

        looping.advance(by: 5)
        oneShot.advance(by: 10)

        #expect(looping.region.source.origin.x == 2)
        #expect(oneShot.isFinished)
        #expect(oneShot.region.source.origin.x == 6)
    }

    @Test
    func spriteIsAnOrdinaryMutableValue() {
        let region = TextureRegion(asset: asset)
        let original = Sprite(region: region)
        var copy = original

        copy.layer = 100
        copy.isFlipped = true

        #expect(original.layer == 0)
        #expect(!original.isFlipped)
        #expect(copy.asset == asset)
        #expect(copy.layer == RenderLayer(100))
        #expect(copy.isFlipped)
    }

    @Test
    func spriteInitializerAcceptsEveryDefaultableProperty() {
        let region = TextureRegion(asset: asset)
        let material = Sprite.Material(
            filtering: .linear,
            addressing: .repeat,
            blendMode: .replace
        )
        let sprite = Sprite(
            region: region,
            material: material,
            layer: 10,
            isFlipped: true
        )

        #expect(sprite.material == material)
        #expect(sprite.layer == 10)
        #expect(sprite.isFlipped)
    }

    @Test
    func materialDefaultsToPixelArtSamplingAndNormalBlending() {
        let material = Sprite.Material()

        #expect(material.filtering == .nearest)
        #expect(material.addressing == .clampToEdge)
        #expect(material.blendMode == .normal)
    }

    @Test
    func materialAllowsIndependentSamplingAxes() {
        var material = Sprite.Material(
            filtering: .init(
                minification: .linear,
                magnification: .nearest
            ),
            addressing: .init(
                horizontal: .repeat,
                vertical: .mirrorRepeat
            )
        )

        #expect(material.filtering.minification == .linear)
        #expect(material.filtering.magnification == .nearest)
        #expect(material.addressing.horizontal == .repeat)
        #expect(material.addressing.vertical == .mirrorRepeat)

        material.filtering.magnification = .linear
        material.addressing.vertical = .clampToEdge

        #expect(material.filtering == .linear)
        #expect(material.addressing == .init(
            horizontal: .repeat,
            vertical: .clampToEdge
        ))
    }

    @Test
    func renderLayersSupportOrderingAndOffsets() {
        let background: RenderLayer = 0
        let player: RenderLayer = 100

        #expect(background < player)
        #expect(player + 50 == RenderLayer(150))
        #expect(player - 50 == RenderLayer(50))
    }
}
