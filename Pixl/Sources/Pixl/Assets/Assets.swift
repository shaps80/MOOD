import PixlFoundation
import PixlGraphics
import PixlPlatform
import Swift

/// Context-owned loader and cache for game texture and sound assets.
public final class Assets {
    private let device: (any Device)?
    private let audioDevice: (any AudioDevice)?
    private let source: (any AssetSource)?
    private let prepareTexture: TexturePreparation
    private let decodeSound: SoundDecode
    private let textureWriter: (Texture) -> (any TextureWriter)?
    private let soundWriter: (Sound) -> (any SoundWriter)?
    let textureResources: TextureResources?
    private var textures: [TextureCacheKey: TextureAsset] = [:]
    private var sounds: [AssetPath: SoundAsset] = [:]
    private var reloadContinuation: AsyncStream<AssetReloadEvent>.Continuation?
    private var reloadTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?

    init(
        device: (any Device)?,
        audioDevice: (any AudioDevice)? = nil,
        source: (any AssetSource)?,
        decode: @escaping TextureDecode = PNGDecoder.decode,
        decodeSound: @escaping SoundDecode = WAVDecoder.decode,
        textureWriter: ((Texture) -> (any TextureWriter)?)? = nil,
        soundWriter: ((Sound) -> (any SoundWriter)?)? = nil
    ) {
        self.device = device
        self.audioDevice = audioDevice
        self.source = source
        let prepareTexture = TexturePreparation(decode: decode)
        self.prepareTexture = prepareTexture
        self.decodeSound = decodeSound
        textureResources = device.map(TextureResources.init(device:))
        self.textureWriter = textureWriter ?? { texture in
            device?.textureWriter(for: texture)
        }
        self.soundWriter = soundWriter ?? { sound in
            audioDevice?.soundWriter(for: sound)
        }

        guard let source, let changes = source.changes else { return }
        let (events, continuation) = AsyncStream<AssetReloadEvent>.makeStream()
        reloadContinuation = continuation

        let reloader = AssetReloader(
            source: source,
            prepareTexture: prepareTexture,
            decodeSound: decodeSound
        )
        reloadTask = Task.detached(priority: .utility) {
            await reloader.run(events)
        }
        let monitor = ReloadMonitor()
        monitorTask = Task.detached(priority: .utility) {
            await monitor.run(changes) { change in
                continuation.yield(.change(change))
            }
        }
    }

    deinit {
        monitorTask?.cancel()
        reloadContinuation?.finish()
        reloadTask?.cancel()
        if let audioDevice {
            for asset in sounds.values {
                audioDevice.destroy(asset.sound)
            }
        }
    }

    /// Loads or returns the cached logical texture asset at a relative path.
    /// Decoded PNG channels are premultiplied by default. Pass `.passthrough`
    /// when the original RGBA channels must remain unchanged; sprite rendering
    /// automatically selects composition compatible with the returned asset.
    /// - Parameters:
    ///   - path: Source-relative image path.
    ///   - alpha: Processing applied to decoded RGB before GPU upload.
    /// - Returns: A stable logical texture asset shared by repeated loads.
    /// - Throws: ``AssetError`` when assets are unavailable, bytes cannot be read or decoded, or GPU creation fails.
    public func load(
        texture path: String,
        alpha: TextureAlpha = .premultiplied
    ) throws(AssetError) -> TextureAsset {
        try loadTexture(path, alpha: alpha)
    }

    /// Loads or returns the cached resident sound asset at a relative path.
    /// - Parameter path: Source-relative sound path.
    /// - Returns: A shared resident sound asset.
    /// - Throws: ``AssetError`` when assets are unavailable, bytes cannot be read or decoded, or audio creation fails.
    public func load(
        sound path: String
    ) throws(AssetError) -> SoundAsset {
        try loadSound(path)
    }

    private func loadTexture(
        _ value: String,
        alpha: TextureAlpha
    ) throws(AssetError) -> TextureAsset {
        let path = try makePath(value)
        let key = TextureCacheKey(path: path, alpha: alpha)
        if let texture = textures[key] {
            return texture
        }

        guard let device, let source, let textureResources else {
            throw .unavailable
        }

        let bytes: [UInt8]
        do {
            bytes = try source.read(path)
        } catch {
            throw assetError(error)
        }

        let decoded = try prepareTexture.prepare(
            bytes,
            path: path,
            alpha: alpha
        )
        let texture = try makeTexture(decoded, on: device)
        let resource = textureResources.insert(texture)
        let asset = TextureAsset(
            identity: resource.rawValue,
            size: SIMD2(decoded.width, decoded.height),
            alpha: alpha
        )
        textures[key] = asset
        if let writer = textureWriter(texture) {
            reloadContinuation?.yield(
                .registerTexture(
                    path: path,
                    size: texture.descriptor.size,
                    alpha: alpha,
                    writer: writer
                )
            )
        }
        return asset
    }

    func texture(for asset: TextureAsset) -> Texture? {
        textureResources?.texture(
            for: TextureResourceID(rawValue: asset.identity)
        )
    }

    func texture(for resource: TextureResourceID) -> Texture? {
        textureResources?.texture(for: resource)
    }

    private func loadSound(
        _ value: String
    ) throws(AssetError) -> SoundAsset {
        let path = try makePath(value)
        if let sound = sounds[path] {
            return sound
        }

        guard let audioDevice, let source else {
            throw .unavailable
        }

        let bytes: [UInt8]
        do {
            bytes = try source.read(path)
        } catch {
            throw assetError(error)
        }

        let decoded = try decodeSound(bytes, path)
        let sound: Sound
        do {
            sound = try audioDevice.makeSound(
                copying: decoded.samples,
                descriptor: decoded.descriptor
            )
        } catch {
            throw .soundCreation(error)
        }

        let asset = SoundAsset(path: path, sound: sound)
        sounds[path] = asset
        if let writer = soundWriter(sound) {
            reloadContinuation?.yield(
                .registerSound(path: path, writer: writer)
            )
        }
        return asset
    }

    private func makePath(
        _ value: String
    ) throws(AssetError) -> AssetPath {
        do {
            return try AssetPath(value)
        } catch {
            throw .invalidPath(value)
        }
    }

    private func makeTexture(
        _ decoded: DecodedTexture,
        on device: any Device
    ) throws(AssetError) -> Texture {
        let descriptor = TextureDescriptor(
            size: TextureSize(
                width: decoded.width,
                height: decoded.height
            ),
            format: .rgba8Unorm,
            usage: [.sampled, .copyDestination]
        )

        do {
            return try device.makeTexture(
                copying: decoded.bytes,
                descriptor: descriptor,
                bytesPerRow: decoded.bytesPerRow
            )
        } catch {
            throw .textureCreation(error)
        }
    }
}

private struct TextureCacheKey: Hashable {
    let path: AssetPath
    let alpha: TextureAlpha
}
