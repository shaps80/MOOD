import PixlPlatform
import Swift

typealias TextureDecode = @Sendable (
    [UInt8],
    AssetPath
) throws(AssetError) -> DecodedTexture

struct ReloadMonitor: Sendable {
    let source: any AssetSource
    let changes: AsyncStream<AssetChange>
    let state: ReloadState
    let decode: TextureDecode

    func run() async {
        for await change in changes {
            guard !Task.isCancelled,
                  state.contains(change.path)
            else {
                continue
            }

            do {
                try await Task.sleep(for: .milliseconds(75))
            } catch is CancellationError {
                return
            } catch {
                return
            }

            let bytes: [UInt8]
            do {
                bytes = try source.read(change.path)
            } catch {
                state.queue(
                    .failure(assetError(error)),
                    for: change.path
                )
                continue
            }

            do {
                let texture = try decode(bytes, change.path)
                state.queue(.success(texture), for: change.path)
            } catch {
                state.queue(.failure(error), for: change.path)
            }
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
