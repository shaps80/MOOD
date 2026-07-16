import Swift

public protocol AssetSource: Sendable {
    var changes: AsyncStream<AssetChange>? { get }

    func read(
        _ path: AssetPath
    ) throws(AssetSourceError) -> [UInt8]
}

public extension AssetSource {
    var changes: AsyncStream<AssetChange>? { nil }
}

public enum AssetSourceError: Error, Hashable, Sendable {
    case invalidPath(String)
    case notFound(AssetPath)
    case unreadable(AssetPath)
}
