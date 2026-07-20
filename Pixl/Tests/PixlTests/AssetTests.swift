import Foundation
import Pixl2D
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

private func decodeSpriteSheetTestTexture(
    _ bytes: [UInt8],
    path: AssetPath
) throws(AssetError) -> DecodedTexture {
    DecodedTexture(
        width: 4,
        height: 2,
        bytes: Array(repeating: bytes.first ?? 0, count: 4 * 2 * 4)
    )
}

private func decodeAlphaTestTexture(
    _ bytes: [UInt8],
    path: AssetPath
) throws(AssetError) -> DecodedTexture {
    DecodedTexture(
        width: 2,
        height: 1,
        bytes: [200, 100, 50, 128, 17, 23, 31, 0]
    )
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

    var lastWrite: [UInt8]? {
        writes.last
    }
}

private actor TestSoundWriter: SoundWriter {
    private var writes: [[Float]] = []
    private var invalidations = 0

    func write(
        copying samples: [Float],
        descriptor: SoundDescriptor
    ) async throws(AudioError) {
        writes.append(samples)
    }

    func invalidate() {
        invalidations += 1
    }

    var writeCount: Int {
        writes.count
    }

    var invalidationCount: Int {
        invalidations
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

private func waitForInvalidation(
    from writer: TestSoundWriter
) async throws {
    for _ in 0..<50 {
        guard await writer.invalidationCount == 0 else { return }
        try await Task.sleep(for: .milliseconds(10))
    }
}

@Suite("Assets")
struct AssetTests {
    @Test
    func processesSpriteAlphaDuringColdLoading() throws {
        let path = try AssetPath("alpha.png")
        let decoded = try decodeAlphaTestTexture([], path: path)

        #expect(decoded.processing(alpha: .passthrough).bytes == decoded.bytes)
        #expect(
            decoded.processing(alpha: .premultiplied).bytes
                == [100, 50, 25, 128, 0, 0, 0, 0]
        )
    }

    @Test
    func cachesTextureAlphaVariantsIndependently() throws {
        let path = try AssetPath("player.png")
        let source = TestAssetSource(path: path, bytes: [1])
        let device = try #require(
            MetalDevice(
                bufferCapacity: 1,
                pipelineCapacity: 1,
                samplerCapacity: 1,
                textureCapacity: 2
            )
        )
        let assets = Assets(
            device: device,
            source: source,
            decode: decodeTestTexture
        )

        let premultiplied = try assets.load(texture: path.value)
        let cached = try assets.load(texture: path.value)
        let passthrough = try assets.load(
            texture: path.value,
            alpha: .passthrough
        )

        #expect(premultiplied == cached)
        #expect(premultiplied != passthrough)
        #expect(premultiplied.alpha == .premultiplied)
        #expect(passthrough.alpha == .passthrough)
    }

    @Test
    func hotReloadReappliesRegisteredAlphaProcessing() async throws {
        let path = try AssetPath("player.png")
        let source = TestAssetSource(path: path, bytes: [1])
        let writer = TestTextureWriter()
        let (events, continuation) = AsyncStream<ReloadEvent>.makeStream()
        let monitor = ReloadMonitor(
            source: source,
            decodeTexture: decodeAlphaTestTexture,
            decodeSound: decodeTestSound
        )
        let task = Task { await monitor.run(events) }
        defer {
            continuation.finish()
            task.cancel()
        }

        continuation.yield(
            .registerTexture(
                path: path,
                size: TextureSize(width: 2, height: 1),
                alpha: .premultiplied,
                writer: writer
            )
        )
        continuation.yield(
            .change(AssetChange(path: path, kind: .modified))
        )
        try await waitForWrite(from: writer)

        #expect(await writer.lastWrite == [100, 50, 25, 128, 0, 0, 0, 0])
    }

    @Test
    func createsSpriteSheetAndAdvancesAnimationTimeline() throws {
        let path = try AssetPath("player.png")
        let source = TestAssetSource(path: path, bytes: [1])
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
            decode: decodeSpriteSheetTestTexture
        )
        let asset = try assets.load(texture: path.value)
        let sheet = SpriteSheet(asset: asset, columns: 4, rows: 1)

        #expect(sheet.regions.count == 4)
        #expect(sheet.region(column: 2, row: 0).source.origin.x == 2)
        #expect(sheet.region(column: 2, row: 0).source.size.y == 2)

        let packedSheet = SpriteSheet(asset: asset, columns: 2, rows: 2)
        let horizontal = packedSheet[row: 1, columns: 0...1]
        #expect(horizontal.map(\.source.origin.x) == [0, 2])
        #expect(horizontal.map(\.source.origin.y) == [1, 1])
        #expect(packedSheet[row: 1, columns: 1...].count == 1)
        #expect(packedSheet[row: 1, columns: ...0].count == 1)
        #expect(packedSheet[row: 1].count == 2)
        let vertical = packedSheet[column: 1, rows: 0...1]
        #expect(vertical.map(\.source.origin.x) == [2, 2])
        #expect(vertical.map(\.source.origin.y) == [0, 1])
        #expect(packedSheet[column: 1, rows: 1...].count == 1)
        #expect(packedSheet[column: 1, rows: ...0].count == 1)
        #expect(packedSheet[column: 1].count == 2)

        var looping = SpriteAnimation.Timeline(
            animation: SpriteAnimation(
                frames: sheet.regions,
                frameDuration: 1
            )
        )
        looping.advance(by: 1)
        #expect(looping.region.source.origin.x == 1)
        looping.advance(by: 3)
        #expect(looping.region.source.origin.x == 0)

        var oneShot = SpriteAnimation.Timeline(
            animation: SpriteAnimation(
                frames: sheet.regions,
                frameDuration: 1,
                loops: false
            )
        )
        oneShot.advance(by: 10)
        #expect(oneShot.isFinished)
        #expect(oneShot.region.source.origin.x == 3)
    }

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
    func removalInvalidatesRegisteredSound() async throws {
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
        continuation.yield(
            .change(AssetChange(path: path, kind: .removed))
        )
        try await waitForInvalidation(from: writer)

        #expect(await writer.invalidationCount == 1)
        #expect(await writer.writeCount == 0)
    }

    @Test
    func coalescesSoundChangeBurstsIntoOneReload() async throws {
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
        for _ in 0..<3 {
            continuation.yield(
                .change(AssetChange(path: path, kind: .modified))
            )
        }
        try await Task.sleep(for: .milliseconds(350))

        #expect(await writer.writeCount == 1)
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

        let first = try assets.load(texture: path.value)
        let cached = try assets.load(texture: path.value)
        let initialTexture = try #require(assets.texture(for: first))

        #expect(first == cached)
        #expect(first.size == SIMD2(1, 1))

        source.change(path, bytes: [2])
        try await waitForWrite(from: writer)

        #expect(await writer.writeCount == 1)
        #expect(assets.texture(for: first) == initialTexture)

        source.change(path, bytes: [0])
        try await Task.sleep(for: .milliseconds(200))

        #expect(await writer.writeCount == 1)
        #expect(assets.texture(for: first) == initialTexture)
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
        let texture = try #require(assets.texture(for: asset))

        source.change(path, bytes: [2])
        try await Task.sleep(for: .milliseconds(200))

        #expect(await writer.writeCount == 0)
        #expect(assets.texture(for: asset) == texture)
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
