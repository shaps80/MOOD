import Swift

/// A normalized, source-relative asset path.
public struct AssetPath: Hashable, Sendable {
    /// Normalized path using forward-slash separators.
    public let value: String

    /// Validates and normalizes a source-relative path.
    /// - Parameter value: Nonempty relative path without backslashes, `.` components, or `..` components.
    /// - Throws: ``AssetSourceError/invalidPath(_:)`` when `value` is not a safe relative path.
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
