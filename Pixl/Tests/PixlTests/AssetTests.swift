import Foundation
import PixlPlatform
import Testing
@testable import Pixl
@testable import PixlMetalPlatform

private final class TestAssetSource: AssetSource, @unchecked Sendable {
    let changes: AsyncStream<AssetChange>?

    private let lock = NSLock()
    private let continuation: AsyncStream<AssetChange>.Continuation
    private var bytes: [AssetPath: [UInt8]]

    init(path: AssetPath, bytes: [UInt8]) {
        var continuation: AsyncStream<AssetChange>.Continuation!
        changes = AsyncStream {
            continuation = $0
        }
        self.continuation = continuation
        self.bytes = [path: bytes]
    }

    func read(
        _ path: AssetPath
    ) throws(AssetSourceError) -> [UInt8] {
        lock.lock()
        defer { lock.unlock() }
        guard let bytes = bytes[path] else {
            throw .notFound(path)
        }
        return bytes
    }

    func change(_ path: AssetPath, bytes: [UInt8]) {
        lock.lock()
        self.bytes[path] = bytes
        lock.unlock()
        continuation.yield(
            AssetChange(path: path, kind: .modified)
        )
    }
}

private func decodeTestTexture(
    _ bytes: [UInt8],
    path: AssetPath
) throws(AssetError) -> DecodedTexture {
    guard bytes.first != 0 else {
        throw .invalidTexture(path.value)
    }
    return DecodedTexture(
        width: 1,
        height: 1,
        bytes: [bytes[0], 0, 0, 255]
    )
}

private func decodeResizableTestTexture(
    _ bytes: [UInt8],
    path: AssetPath
) throws(AssetError) -> DecodedTexture {
    guard bytes.first != 2 else {
        return DecodedTexture(
            width: 2,
            height: 1,
            bytes: [2, 0, 0, 255, 2, 0, 0, 255]
        )
    }
    return try decodeTestTexture(bytes, path: path)
}

private actor TestTextureWriter: TextureWriter {
    private var writes: [[UInt8]] = []

    func write(
        copying bytes: [UInt8],
        bytesPerRow: UInt32
    ) async throws(DeviceError) {
        writes.append(bytes)
    }

    var writeCount: Int {
        writes.count
    }
}

private func waitForWrite(
    from writer: TestTextureWriter
) async throws {
    for _ in 0..<50 {
        guard await writer.writeCount == 0 else { return }
        try await Task.sleep(for: .milliseconds(10))
    }
}

@Suite("Assets")
struct AssetTests {
    @Test
    func createsBuiltInTexturedPipelineAndSampler() throws {
        let device = try #require(
            MetalDevice(
                bufferCapacity: 1,
                pipelineCapacity: 1,
                samplerCapacity: 1,
                textureCapacity: 1
            )
        )
        let layout = VertexLayout(
            bufferCapacity: 1,
            attributeCapacity: 3
        )
        layout.append(
            VertexBufferLayout(bufferIndex: 0, stride: 32)
        )
        layout.append(
            VertexAttribute(
                location: 0,
                bufferIndex: 0,
                format: .float32x2,
                offset: 0
            )
        )
        layout.append(
            VertexAttribute(
                location: 1,
                bufferIndex: 0,
                format: .float32x4,
                offset: 8
            )
        )
        layout.append(
            VertexAttribute(
                location: 2,
                bufferIndex: 0,
                format: .float32x2,
                offset: 24
            )
        )

        let pipeline = try device.makeRenderPipeline(
            RenderPipelineDescriptor(
                vertex: .texturedVertex,
                fragment: .texturedFragment,
                vertexLayout: layout,
                colorFormat: .bgra8Unorm
            )
        )
        let sampler = try device.makeSampler(
            SamplerDescriptor()
        )

        device.destroy(pipeline)
        device.destroy(sampler)
    }

    @Test
    func decodesPNG() throws {
        let bytes = try #require(
            Data(
                base64Encoded:
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC"
                    + "AAAAC0lEQVR42mP8/x8AAusB9Y9ZlYQAAAAASUVORK5CYII="
            )
        )
        let decoded = try PNGDecoder.decode(
            Array(bytes),
            path: AssetPath("pixel.png")
        )

        #expect(decoded.width == 1)
        #expect(decoded.height == 1)
        #expect(decoded.bytes.count == 4)
    }

    @Test
    func writesExistingMetalTexture() async throws {
        let device = try #require(
            MetalDevice(
                bufferCapacity: 1,
                pipelineCapacity: 1,
                samplerCapacity: 1,
                textureCapacity: 1
            )
        )
        let descriptor = TextureDescriptor(
            size: TextureSize(width: 1, height: 1),
            format: .rgba8Unorm,
            usage: [.sampled, .copyDestination]
        )
        let texture = try device.makeTexture(
            copying: [1, 0, 0, 255],
            descriptor: descriptor,
            bytesPerRow: 4
        )
        let writer = try #require(device.textureWriter(for: texture))

        try await writer.write(
            copying: [2, 0, 0, 255],
            bytesPerRow: 4
        )

        device.destroy(texture)
    }

    @Test
    func cachesAndReloadsStableTextureHandles() async throws {
        let path = try AssetPath("player.png")
        let source = TestAssetSource(path: path, bytes: [1])
        let writer = TestTextureWriter()
        let device = try #require(
            MetalDevice(
                bufferCapacity: 1,
                pipelineCapacity: 1,
                samplerCapacity: 1,
                textureCapacity: 4
            )
        )
        let assets = Assets(
            device: device,
            source: source,
            decode: decodeTestTexture,
            textureWriter: { _ in writer }
        )

        let first = try assets.load(texture: path.value)
        let cached = try assets.load(texture: path.value)
        let initialTexture = first.texture

        #expect(first === cached)

        source.change(path, bytes: [2])
        try await waitForWrite(from: writer)

        #expect(await writer.writeCount == 1)
        #expect(first.texture == initialTexture)

        source.change(path, bytes: [0])
        try await Task.sleep(for: .milliseconds(200))

        #expect(await writer.writeCount == 1)
        #expect(first.texture == initialTexture)
    }

    @Test
    func retainsTextureWhenReloadDimensionsChange() async throws {
        let path = try AssetPath("player.png")
        let source = TestAssetSource(path: path, bytes: [1])
        let writer = TestTextureWriter()
        let device = try #require(
            MetalDevice(
                bufferCapacity: 1,
                pipelineCapacity: 1,
                samplerCapacity: 1,
                textureCapacity: 1
            )
        )
        let assets = Assets(
            device: device,
            source: source,
            decode: decodeResizableTestTexture,
            textureWriter: { _ in writer }
        )
        let asset = try assets.load(texture: path.value)
        let texture = asset.texture

        source.change(path, bytes: [2])
        try await Task.sleep(for: .milliseconds(200))

        #expect(await writer.writeCount == 0)
        #expect(asset.texture == texture)
    }
}
