import Swift

package struct CheckFailure: Error, CustomStringConvertible, Sendable {
    package let description: String

    package init(_ description: String) {
        self.description = description
    }
}

package func require(
    _ condition: @autoclosure () -> Bool,
    _ description: String
) throws {
    guard condition() else { throw CheckFailure(description) }
}

