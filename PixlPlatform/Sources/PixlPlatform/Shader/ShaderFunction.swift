import Swift

public struct ShaderFunction: Sendable {
    public let name: String

    public init(name: String) {
        precondition(!name.isEmpty, "Shader function name must not be empty")
        self.name = name
    }
}

public extension ShaderFunction {
    static let vertex = Self(name: "pixlVertex")
    static let fragment = Self(name: "pixlFragment")
}
