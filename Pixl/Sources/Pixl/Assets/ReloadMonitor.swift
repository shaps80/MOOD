import PixlPlatform
import Swift

typealias TextureDecode = @Sendable (
    [UInt8],
    AssetPath
) throws(AssetError) -> DecodedTexture

struct ReloadMonitor: Sendable {
    let source: any AssetSource
    let decode: TextureDecode

    func run(_ events: AsyncStream<ReloadEvent>) async {
        var targets: [AssetPath: ReloadTarget] = [:]

        for await event in events {
            guard !Task.isCancelled else { return }

            switch event {
            case .register(let path, let size, let writer):
                targets[path] = ReloadTarget(size: size, writer: writer)

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

        let decoded: DecodedTexture
        do {
            decoded = try decode(bytes, path)
        } catch {
            report(error, for: path)
            return
        }

        guard decoded.width == target.size.width,
              decoded.height == target.size.height
        else {
            report(
                AssetError.invalidTexture(path.value),
                for: path,
                reason: "dimensions changed from "
                    + "\(target.size.width)x\(target.size.height) to "
                    + "\(decoded.width)x\(decoded.height)"
            )
            return
        }

        do {
            try await target.writer.write(
                copying: decoded.bytes,
                bytesPerRow: decoded.bytesPerRow
            )
            print("Reloaded texture '\(path.value)'")
        } catch {
            report(error, for: path)
        }
    }

    private func report(
        _ error: any Error,
        for path: AssetPath,
        reason: String? = nil
    ) {
        if let reason {
            print(
                "Unable to reload texture '\(path.value)': "
                    + "\(error) (\(reason))"
            )
        } else {
            print("Unable to reload texture '\(path.value)': \(error)")
        }
    }
}

enum ReloadEvent: Sendable {
    case register(
        path: AssetPath,
        size: TextureSize,
        writer: any TextureWriter
    )
    case change(AssetChange)
}

private struct ReloadTarget: Sendable {
    let size: TextureSize
    let writer: any TextureWriter
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
