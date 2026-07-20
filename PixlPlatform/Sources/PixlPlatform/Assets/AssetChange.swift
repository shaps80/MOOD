import Swift

/// A change reported by a live asset source.
public struct AssetChange: Hashable, Sendable {
    /// The kind of filesystem-style change.
    public enum Kind: Hashable, Sendable {
        /// A new asset became available.
        case created
        /// An existing asset's contents changed.
        case modified
        /// An asset is no longer available.
        case removed
    }

    /// Relative path of the changed asset.
    public let path: AssetPath
    /// Kind of change that occurred.
    public let kind: Kind

    /// Creates an asset-change event.
    /// - Parameters:
    ///   - path: Relative path of the changed asset.
    ///   - kind: Kind of change that occurred.
    public init(path: AssetPath, kind: Kind) {
        self.path = path
        self.kind = kind
    }
}
