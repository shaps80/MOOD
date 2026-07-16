import Swift

public struct AssetChange: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case created
        case modified
        case removed
    }

    public let path: AssetPath
    public let kind: Kind

    public init(path: AssetPath, kind: Kind) {
        self.path = path
        self.kind = kind
    }
}
