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

private func decodeTestSound(
    _ bytes: [UInt8],
    path: AssetPath
) throws(AssetError) -> DecodedSound {
    guard let value = bytes.first, value != 0 else {
        throw .invalidSound(path.value)
    }
    return DecodedSound(
        samples: [Float(value) / 255],
        descriptor: SoundDescriptor(
            sampleRate: 44_100,
            channelLayout: .mono,
            frameCount: 1
        )
    )
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

private actor TestSoundWriter: SoundWriter {
    private var writes: [[Float]] = []

    func write(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) async throws(AudioError) {
        writes.append(samples)
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

private func waitForWrite(
    from writer: TestSoundWriter
) async throws {
    for _ in 0..<50 {
        guard await writer.writeCount == 0 else { return }
        try await Task.sleep(for: .milliseconds(10))
    }
}

@Suite("Assets")
struct AssetTests {
    @Test
    func decodesStereoPCM16WAVToPlanarFloatSamples() throws {
        let bytes = makePCM16WAV(
            channelCount: 2,
            sampleRate: 44_100,
            interleavedSamples: [
                .min, .max,
                0, 16_384
            ]
        )
        let decoded = try WAVDecoder.decode(
            bytes,
            path: AssetPath("sound.wav")
        )

        #expect(decoded.descriptor.sampleRate == 44_100)
        #expect(decoded.descriptor.channelLayout == .stereo)
        #expect(decoded.descriptor.frameCount == 2)
        #expect(decoded.samples[0] == -1)
        #expect(decoded.samples[1] == 0)
        #expect(decoded.samples[2] > 0.999)
        #expect(decoded.samples[3] == 0.5)
    }

    @Test
    func rejectsUnsupportedMultichannelWAV() throws {
        let bytes = makePCM16WAV(
            channelCount: 3,
            sampleRate: 44_100,
            interleavedSamples: [0, 0, 0]
        )

        #expect(throws: AssetError.self) {
            try WAVDecoder.decode(
                bytes,
                path: AssetPath("surround.wav")
            )
        }
    }

    @Test
    func reloadsRegisteredSoundsAndRetainsLastGoodData() async throws {
        let path = try AssetPath("jump.wav")
        let source = TestAssetSource(path: path, bytes: [1])
        let writer = TestSoundWriter()
        let (events, continuation) = AsyncStream<ReloadEvent>.makeStream()
        let monitor = ReloadMonitor(
            source: source,
            decodeTexture: decodeTestTexture,
            decodeSound: decodeTestSound
        )
        let task = Task {
            await monitor.run(events)
        }
        defer {
            continuation.finish()
            task.cancel()
        }

        continuation.yield(.registerSound(path: path, writer: writer))
        source.change(path, bytes: [2])
        continuation.yield(
            .change(AssetChange(path: path, kind: .modified))
        )
        try await waitForWrite(from: writer)
        #expect(await writer.writeCount == 1)

        source.change(path, bytes: [0])
        continuation.yield(
            .change(AssetChange(path: path, kind: .modified))
        )
        try await Task.sleep(for: .milliseconds(200))
        #expect(await writer.writeCount == 1)
    }

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
                vertex: .vertex,
                fragment: .fragment,
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
                    + "AAAAC0lEQVR4nGP4/x8AAwAB//wl3FEAAAAASUVORK5CYII="
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

        let first = try #require(assets.load(texture: path.value))
        let cached = try #require(assets.load(texture: path.value))
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
        let asset = try #require(assets.load(texture: path.value))
        let texture = asset.texture

        source.change(path, bytes: [2])
        try await Task.sleep(for: .milliseconds(200))

        #expect(await writer.writeCount == 0)
        #expect(asset.texture == texture)
    }
}

private func makePCM16WAV(
    channelCount: UInt16,
    sampleRate: UInt32,
    interleavedSamples: [Int16]
) -> [UInt8] {
    let dataSize = UInt32(interleavedSamples.count * 2)
    let blockAlignment = channelCount * 2
    var bytes: [UInt8] = []
    bytes.append(contentsOf: [82, 73, 70, 70])
    append(UInt32(36) + dataSize, to: &bytes)
    bytes.append(contentsOf: [87, 65, 86, 69])
    bytes.append(contentsOf: [102, 109, 116, 32])
    append(UInt32(16), to: &bytes)
    append(UInt16(1), to: &bytes)
    append(channelCount, to: &bytes)
    append(sampleRate, to: &bytes)
    append(sampleRate * UInt32(blockAlignment), to: &bytes)
    append(blockAlignment, to: &bytes)
    append(UInt16(16), to: &bytes)
    bytes.append(contentsOf: [100, 97, 116, 97])
    append(dataSize, to: &bytes)
    for sample in interleavedSamples {
        append(UInt16(bitPattern: sample), to: &bytes)
    }
    return bytes
}

private func append(_ value: UInt16, to bytes: inout [UInt8]) {
    bytes.append(UInt8(truncatingIfNeeded: value))
    bytes.append(UInt8(truncatingIfNeeded: value >> 8))
}

private func append(_ value: UInt32, to bytes: inout [UInt8]) {
    bytes.append(UInt8(truncatingIfNeeded: value))
    bytes.append(UInt8(truncatingIfNeeded: value >> 8))
    bytes.append(UInt8(truncatingIfNeeded: value >> 16))
    bytes.append(UInt8(truncatingIfNeeded: value >> 24))
}
