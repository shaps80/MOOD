import JavaScriptKit
import PixlPlatform
import Swift

final class WasmAssetSource: AssetSource, @unchecked Sendable {
    private let assets: JSObject

    init?() {
        guard let assets = JSObject.global.__pixlAssets.object else {
            return nil
        }
        self.assets = assets
    }

    func read(
        _ path: AssetPath
    ) throws(AssetSourceError) -> [UInt8] {
        guard let bytes = JSUint8Array(from: assets[path.value]) else {
            throw .notFound(path)
        }
        return bytes.withUnsafeBytes(Array.init)
    }
}
