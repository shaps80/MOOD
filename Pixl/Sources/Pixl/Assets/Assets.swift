import PixlPlatform
import Swift

public final class Assets {
    private let device: (any Device)?
    private let source: (any AssetSource)?
    private let decode: TextureDecode
    private let textureWriter: (Texture) -> (any TextureWriter)?
    private var textures: [AssetPath: TextureAsset] = [:]
    private var reloadContinuation: AsyncStream<ReloadEvent>.Continuation?
    private var changeTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?

    init(
        device: (any Device)?,
        source: (any AssetSource)?,
        decode: @escaping TextureDecode = PNGDecoder.decode,
        textureWriter: ((Texture) -> (any TextureWriter)?)? = nil
    ) {
        self.device = device
        self.source = source
        self.decode = decode
        self.textureWriter = textureWriter ?? { texture in
            device?.textureWriter(for: texture)
        }

        guard let source, let changes = source.changes else { return }
        let (events, continuation) = AsyncStream<ReloadEvent>.makeStream()
        reloadContinuation = continuation

        let monitor = ReloadMonitor(
            source: source,
            decode: decode
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
        guard let device else { return }
        for asset in textures.values {
            device.destroy(asset.texture)
        }
    }

    public func load(
        texture path: String
    ) -> TextureAsset? {
        do {
            return try loadTexture(path)
        } catch {
            print("Unable to load texture '\(path)': \(error)")
            return nil
        }
    }

    private func loadTexture(
        _ value: String
    ) throws(AssetError) -> TextureAsset {
        let path = try makePath(value)
        if let texture = textures[path] {
            return texture
        }

        guard let device, let source else {
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
        let asset = TextureAsset(path: path, texture: texture)
        textures[path] = asset
        if let writer = textureWriter(texture) {
            reloadContinuation?.yield(
                .register(
                    path: path,
                    size: texture.descriptor.size,
                    writer: writer
                )
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
