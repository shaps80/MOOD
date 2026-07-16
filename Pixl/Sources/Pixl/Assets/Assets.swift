import PixlPlatform
import Swift

public final class Assets {
    private let device: (any Device)?
    private let source: (any AssetSource)?
    private let decode: TextureDecode
    private let reloadState = ReloadState()
    private var textures: [AssetPath: TextureAsset] = [:]
    private var monitorTask: Task<Void, Never>?

    init(
        device: (any Device)?,
        source: (any AssetSource)?,
        decode: @escaping TextureDecode = PNGDecoder.decode
    ) {
        self.device = device
        self.source = source
        self.decode = decode

        guard let source, let changes = source.changes else { return }
        let monitor = ReloadMonitor(
            source: source,
            changes: changes,
            state: reloadState,
            decode: decode
        )
        monitorTask = Task.detached(priority: .utility) {
            await monitor.run()
        }
    }

    deinit {
        monitorTask?.cancel()
        guard let device else { return }
        for asset in textures.values {
            device.destroy(asset.texture)
        }
    }

    public func load(
        texture path: String
    ) throws(AssetError) -> TextureAsset {
        let path = try makePath(path)
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
        reloadState.register(path)
        return asset
    }

    func applyChanges() {
        guard let device else { return }
        let pending = reloadState.takePending()

        for path in pending.keys.sorted(by: {
            $0.value < $1.value
        }) {
            guard let asset = textures[path],
                  let result = pending[path]
            else {
                continue
            }

            do {
                let decoded = try result.get()
                let texture = try makeTexture(decoded, on: device)
                let previous = asset.replace(with: texture)
                device.destroy(previous)
                print("Reloaded texture '\(path.value)'")
            } catch {
                print(
                    "Unable to reload texture '\(path.value)': \(error)"
                )
            }
        }
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
