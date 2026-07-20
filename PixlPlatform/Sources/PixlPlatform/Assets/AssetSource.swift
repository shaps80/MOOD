import Swift

/// A platform adapter that supplies bytes for relative asset paths.
public protocol AssetSource: Sendable {
    /// Optional asynchronous stream of asset changes for hot reload.
    var changes: AsyncStream<AssetChange>? { get }

    /// Reads all bytes for an asset.
    /// - Parameter path: Valid source-relative path to read.
    /// - Returns: The asset's complete byte contents.
    /// - Throws: An ``AssetSourceError`` when the path cannot be read.
    func read(
        _ path: AssetPath
    ) throws(AssetSourceError) -> [UInt8]
}

public extension AssetSource {
    /// The default source does not report live changes.
    var changes: AsyncStream<AssetChange>? { nil }
}

/// Failures produced while validating or reading an asset path.
public enum AssetSourceError: Error, Hashable, Sendable {
    /// The supplied string is not a valid source-relative path.
    case invalidPath(String)
    /// No asset exists at the requested path.
    case notFound(AssetPath)
    /// The asset exists but its bytes cannot be read.
    case unreadable(AssetPath)
}
