import PixlPlatform
import Swift

typealias TextureDecode = @Sendable (
    [UInt8],
    AssetPath
) throws(AssetError) -> DecodedTexture

struct ReloadMonitor: Sendable {
    let source: any AssetSource
    let decodeTexture: TextureDecode
    let decodeSound: SoundDecode

    func run(_ events: AsyncStream<ReloadEvent>) async {
        var targets: [AssetPath: ReloadTarget] = [:]

        for await event in events {
            guard !Task.isCancelled else { return }

            switch event {
            case .registerTexture(let path, let size, let writer):
                targets[path] = .texture(size: size, writer: writer)

            case .registerSound(let path, let writer):
                targets[path] = .sound(writer: writer)

            case .change(let change):
                guard let target = targets[change.path] else { continue }
                await reload(change.path, target: target)
            }
        }
    }

    private func reload(
        _ path: AssetPath,
        target: ReloadTarget
    ) async {
        do {
            try await Task.sleep(for: .milliseconds(75))
        } catch {
            return
        }

        guard !Task.isCancelled else { return }

        let bytes: [UInt8]
        do {
            bytes = try source.read(path)
        } catch {
            report(assetError(error), for: path)
            return
        }

        switch target {
        case .texture(let size, let writer):
            await reloadTexture(
                bytes,
                path: path,
                size: size,
                writer: writer
            )

        case .sound(let writer):
            await reloadSound(bytes, path: path, writer: writer)
        }
    }

    private func reloadTexture(
        _ bytes: [UInt8],
        path: AssetPath,
        size: TextureSize,
        writer: any TextureWriter
    ) async {
        let decoded: DecodedTexture
        do {
            decoded = try decodeTexture(bytes, path)
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

enum ReloadEvent: Sendable {
    case registerTexture(
        path: AssetPath,
        size: TextureSize,
        writer: any TextureWriter
    )
    case registerSound(
        path: AssetPath,
        writer: any SoundWriter
    )
    case change(AssetChange)
}

private enum ReloadTarget: Sendable {
    case texture(
        size: TextureSize,
        writer: any TextureWriter
    )
    case sound(writer: any SoundWriter)
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
