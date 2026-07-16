import Testing
@testable import PixlPlatform

@Suite("Asset paths")
struct AssetPathTests {
    @Test
    func normalizesRepeatedSeparators() throws {
        let path = try AssetPath("Sprites//player.png")

        #expect(path.value == "Sprites/player.png")
    }

    @Test(
        arguments: [
            "",
            "/player.png",
            "../player.png",
            "Sprites/../player.png",
            #"Sprites\player.png"#
        ]
    )
    func rejectsPathsOutsideTheMountedRoot(_ value: String) {
        #expect(throws: AssetSourceError.self) {
            try AssetPath(value)
        }
    }
}
