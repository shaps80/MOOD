import PixlPlatform
import Swift

/// A game-facing asset loading or creation failure.
public enum AssetError: Error, Hashable, Sendable {
    /// The current platform does not expose the required asset or device capability.
    case unavailable
    /// The supplied source-relative path is invalid.
    case invalidPath(String)
    /// No asset exists at the supplied path.
    case notFound(String)
    /// Asset bytes could not be read.
    case unreadable(String)
    /// Image format is not supported.
    case unsupportedTexture(String)
    /// Image bytes are malformed or inconsistent.
    case invalidTexture(String)
    /// GPU texture creation failed.
    case textureCreation(DeviceError)
    /// Sound format is not supported.
    case unsupportedSound(String)
    /// Sound bytes are malformed or inconsistent.
    case invalidSound(String)
    /// Resident audio-resource creation failed.
    case soundCreation(AudioError)
}

extension AssetError: CustomStringConvertible {
    /// Human-readable description including the affected path or underlying error.
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
        case .unsupportedSound(let path):
            "Sound format for '\(path)' is unsupported"
        case .invalidSound(let path):
            "Sound '\(path)' is invalid"
        case .soundCreation(let error):
            "Sound creation failed: \(error)"
        }
    }
}
