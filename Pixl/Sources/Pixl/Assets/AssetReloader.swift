import PixlGraphics
import PixlPlatform
import Swift

struct AssetReloader: Sendable {
    let source: any AssetSource
    let prepareTexture: TexturePreparation
    let decodeSound: SoundDecode

    func run(_ events: AsyncStream<AssetReloadEvent>) async {
        var targets: [AssetPath: [Target]] = [:]

        for await event in events {
            guard !Task.isCancelled else { return }

            switch event {
            case .registerTexture(let path, let size, let alpha, let writer):
                targets[path, default: []].append(
                    .texture(size: size, alpha: alpha, writer: writer)
                )

            case .registerSound(let path, let writer):
                targets[path, default: []].append(.sound(writer: writer))

            case .change(let change):
                guard let registered = targets[change.path] else { continue }
                if change.kind == .removed {
                    var retainedTextures: [Target] = []
                    for target in registered {
                        switch target {
                        case .sound(let writer):
                            await invalidateSound(change.path, writer: writer)
                        case .texture:
                            retainedTextures.append(target)
                        }
                    }
                    if !retainedTextures.isEmpty {
                        await reload(change.path, targets: retainedTextures)
                    }
                } else {
                    await reload(change.path, targets: registered)
                }
            }
        }
    }

    private func reload(
        _ path: AssetPath,
        targets: [Target]
    ) async {
        guard !Task.isCancelled else { return }

        let bytes: [UInt8]
        do {
            bytes = try source.read(path)
        } catch {
            if case .notFound = error {
                for target in targets {
                    if case .sound(let writer) = target {
                        await invalidateSound(path, writer: writer)
                    }
                }
            }
            report(assetError(error), for: path)
            return
        }

        for target in targets {
            switch target {
            case .texture(let size, let alpha, let writer):
                await reloadTexture(
                    bytes,
                    path: path,
                    size: size,
                    alpha: alpha,
                    writer: writer
                )

            case .sound(let writer):
                await reloadSound(bytes, path: path, writer: writer)
            }
        }
    }

    private func reloadTexture(
        _ bytes: [UInt8],
        path: AssetPath,
        size: TextureSize,
        alpha: TextureAlpha,
        writer: any TextureWriter
    ) async {
        let decoded: DecodedTexture
        do {
            decoded = try prepareTexture.prepare(
                bytes,
                path: path,
                alpha: alpha
            )
        } catch {
            report(error, kind: "texture", for: path)
            return
        }

        guard decoded.width == size.width,
              decoded.height == size.height
        else {
            report(
                AssetError.invalidTexture(path.value),
                kind: "texture",
                for: path,
                reason: "dimensions changed from "
                    + "\(size.width)x\(size.height) to "
                    + "\(decoded.width)x\(decoded.height)"
            )
            return
        }

        do {
            try await writer.write(
                copying: decoded.bytes,
                bytesPerRow: decoded.bytesPerRow
            )
            print("Reloaded texture '\(path.value)'")
        } catch {
            report(error, kind: "texture", for: path)
        }
    }

    private func reloadSound(
        _ bytes: [UInt8],
        path: AssetPath,
        writer: any SoundWriter
    ) async {
        let decoded: DecodedSound
        do {
            decoded = try decodeSound(bytes, path)
        } catch {
            report(error, kind: "sound", for: path)
            return
        }

        do {
            try await writer.write(
                copying: decoded.samples,
                descriptor: decoded.descriptor
            )
            print("Reloaded sound '\(path.value)'")
        } catch {
            report(error, kind: "sound", for: path)
        }
    }

    private func invalidateSound(
        _ path: AssetPath,
        writer: any SoundWriter
    ) async {
        await writer.invalidate()
        print(
            "Sound unavailable '\(path.value)'; "
                + "active playbacks stopped"
        )
    }

    private func report(
        _ error: any Error,
        kind: String = "asset",
        for path: AssetPath,
        reason: String? = nil
    ) {
        if let reason {
            print(
                "Unable to reload \(kind) '\(path.value)': "
                    + "\(error) (\(reason))"
            )
        } else {
            print("Unable to reload \(kind) '\(path.value)': \(error)")
        }
    }
}

func assetError(_ error: AssetSourceError) -> AssetError {
    switch error {
    case .invalidPath(let path):
        return .invalidPath(path)
    case .notFound(let path):
        return .notFound(path.value)
    case .unreadable(let path):
        return .unreadable(path.value)
    }
}

enum AssetReloadEvent: Sendable {
    case registerTexture(
        path: AssetPath,
        size: TextureSize,
        alpha: TextureAlpha,
        writer: any TextureWriter
    )
    case registerSound(
        path: AssetPath,
        writer: any SoundWriter
    )
    case change(AssetChange)
}

private extension AssetReloader {
    enum Target: Sendable {
        case texture(
            size: TextureSize,
            alpha: TextureAlpha,
            writer: any TextureWriter
        )
        case sound(writer: any SoundWriter)
    }
}
