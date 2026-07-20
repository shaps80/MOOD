import PixlGraphics
import Testing

@Suite("Texture asset")
struct TextureAssetTests {
    @Test
    func copiesPreserveLogicalIdentityAndMetadata() {
        let asset = TextureAsset(
            identity: 42,
            size: SIMD2(64, 32)
        )
        let copy = asset

        #expect(copy == asset)
        #expect(copy.size == SIMD2(64, 32))
        #expect(copy.alpha == .premultiplied)
        #expect(Set([asset, copy]).count == 1)
    }

    @Test
    func distinctLogicalIdentitiesAreNotEquivalent() {
        let first = TextureAsset(identity: 1, size: SIMD2(1, 1))
        let second = TextureAsset(identity: 2, size: SIMD2(1, 1))

        #expect(first != second)
    }
}
