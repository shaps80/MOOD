import Foundation
import PixlPlatform
import Swift

final class ReloadState: @unchecked Sendable {
    private let lock = NSLock()
    private var loaded: Set<AssetPath> = []
    private var pending: [
        AssetPath: Result<DecodedTexture, AssetError>
    ] = [:]

    func register(_ path: AssetPath) {
        lock.lock()
        loaded.insert(path)
        lock.unlock()
    }

    func contains(_ path: AssetPath) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return loaded.contains(path)
    }

    func queue(
        _ result: Result<DecodedTexture, AssetError>,
        for path: AssetPath
    ) {
        lock.lock()
        pending[path] = result
        lock.unlock()
    }

    func takePending() -> [
        AssetPath: Result<DecodedTexture, AssetError>
    ] {
        lock.lock()
        defer { lock.unlock() }
        let result = pending
        pending.removeAll(keepingCapacity: true)
        return result
    }
}
