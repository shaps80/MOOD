import PixlFoundation
import PixlGraphics
import PixlPlatform
import Swift

public final class Assets {
    private let device: (any Device)?
    private let audioDevice: (any AudioDevice)?
    private let source: (any AssetSource)?
    private let decode: TextureDecode
    private let decodeSound: SoundDecode
    private let textureWriter: (Texture) -> (any TextureWriter)?
    private let soundWriter: (Sound) -> (any SoundWriter)?
    private let textureResources: TextureResources?
    private var textures: [AssetPath: TextureAsset] = [:]
    private var sounds: [AssetPath: SoundAsset] = [:]
    private var reloadContinuation: AsyncStream<ReloadEvent>.Continuation?
    private var changeTask: Task<Void, Never>?
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
        self.decode = decode
        self.decodeSound = decodeSound
        textureResources = device.map(TextureResources.init(device:))
        self.textureWriter = textureWriter ?? { texture in
            device?.textureWriter(for: texture)
        }
        self.soundWriter = soundWriter ?? { sound in
            audioDevice?.soundWriter(for: sound)
        }

        guard let source, let changes = source.changes else { return }
        let (events, continuation) = AsyncStream<ReloadEvent>.makeStream()
        reloadContinuation = continuation

        let monitor = ReloadMonitor(
            source: source,
            decodeTexture: decode,
            decodeSound: decodeSound
        )
        monitorTask = Task.detached(priority: .utility) {
            await monitor.run(events)
        }
        changeTask = Task.detached(priority: .utility) {
            for await change in changes {
                guard !Task.isCancelled else { return }
                continuation.yield(.change(change))
            }
        }
    }

    deinit {
        changeTask?.cancel()
        reloadContinuation?.finish()
        monitorTask?.cancel()
        if let audioDevice {
            for asset in sounds.values {
                audioDevice.destroy(asset.sound)
            }
        }
    }

    public func load(
        texture path: String
    ) throws(AssetError) -> TextureAsset {
        try loadTexture(path)
    }

    public func load(
        sound path: String
    ) throws(AssetError) -> SoundAsset {
        try loadSound(path)
    }

    private func loadTexture(
        _ value: String
    ) throws(AssetError) -> TextureAsset {
        let path = try makePath(value)
        if let texture = textures[path] {
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

        let decoded = try decode(bytes, path)
        let texture = try makeTexture(decoded, on: device)
        let resource = textureResources.insert(texture)
        let asset = TextureAsset(
            identity: resource.rawValue,
            size: SIMD2(decoded.width, decoded.height)
        )
        textures[path] = asset
        if let writer = textureWriter(texture) {
            reloadContinuation?.yield(
                .registerTexture(
                    path: path,
                    size: texture.descriptor.size,
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
