import JavaScriptKit
import PixlPlatform
import Swift

enum WasmBuiltinAssets {
    static func read(_ path: String) -> [UInt8]? {
        guard let assets = JSObject.global.__pixlAssets.object,
              let bytes = JSUint8Array(from: assets[path]) else {
            return nil
        }
        return bytes.withUnsafeBytes(Array.init)
    }
}

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
        guard !path.value.hasPrefix("__pixl/") else {
            throw .notFound(path)
        }
        guard let bytes = JSUint8Array(from: assets[path.value]) else {
            throw .notFound(path)
        }
        return bytes.withUnsafeBytes(Array.init)
    }
}
