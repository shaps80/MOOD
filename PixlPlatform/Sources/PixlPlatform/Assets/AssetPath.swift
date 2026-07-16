import Swift

public struct AssetPath: Hashable, Sendable {
    public let value: String

    public init(_ value: String) throws(AssetSourceError) {
        guard !value.isEmpty,
              !value.hasPrefix("/"),
              !value.contains("\\")
        else {
            throw .invalidPath(value)
        }

        let components = value.split(
            separator: "/",
            omittingEmptySubsequences: true
        )
        guard !components.isEmpty,
              components.allSatisfy({ $0 != "." && $0 != ".." })
        else {
            throw .invalidPath(value)
        }

        self.value = components.joined(separator: "/")
    }
}
