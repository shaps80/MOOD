import PixlPlatform
import Swift

public enum AssetError: Error, Hashable, Sendable {
    case unavailable
    case invalidPath(String)
    case notFound(String)
    case unreadable(String)
    case unsupportedTexture(String)
    case invalidTexture(String)
    case textureCreation(DeviceError)
}

extension AssetError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unavailable:
            "Assets are unavailable on this platform"
        case .invalidPath(let path):
            "Invalid asset path '\(path)'"
        case .notFound(let path):
            "Asset '\(path)' was not found"
        case .unreadable(let path):
            "Asset '\(path)' could not be read"
        case .unsupportedTexture(let path):
            "Texture format for '\(path)' is unsupported"
        case .invalidTexture(let path):
            "Texture '\(path)' is invalid"
        case .textureCreation(let error):
            "Texture creation failed: \(error)"
        }
    }
}
