import PixlFoundation
import PixlPlatform
import Testing
@testable import PixlMetalPlatform

@Suite("Texture resources")
struct TextureResourcesTests {
    @Test
    func resolvesReplacesAndInvalidatesLogicalIdentities() throws {
        let device = try #require(
            MetalDevice(
                bufferCapacity: 1,
                pipelineCapacity: 1,
                samplerCapacity: 1,
                textureCapacity: 2
            )
        )
        let resources = TextureResources(device: device)
        let first = try makeTexture(1, on: device)
        let id = resources.insert(first)

        #expect(resources.texture(for: id) == first)

        let replacement = try makeTexture(2, on: device)
        #expect(resources.replace(replacement, for: id))
        #expect(resources.texture(for: id) == replacement)

        #expect(resources.remove(id))
        #expect(resources.texture(for: id) == nil)
        #expect(!resources.remove(id))
    }

    @Test
    func destroysOwnedTexturesWithTheStore() throws {
        let device = try #require(
            MetalDevice(
                bufferCapacity: 1,
                pipelineCapacity: 1,
                samplerCapacity: 1,
                textureCapacity: 1
            )
        )

        do {
            let resources = TextureResources(device: device)
            _ = resources.insert(try makeTexture(1, on: device))
        }

        let texture = try makeTexture(2, on: device)
        device.destroy(texture)
    }

    private func makeTexture(
        _ value: UInt8,
        on device: any Device
    ) throws -> Texture {
        try device.makeTexture(
            copying: [value, 0, 0, 255],
            descriptor: TextureDescriptor(
                size: TextureSize(width: 1, height: 1),
                format: .rgba8Unorm,
                usage: [.sampled, .copyDestination]
            ),
            bytesPerRow: 4
        )
    }
}
