import Swift

public struct ShaderFunction: Sendable {
    public let shader: Shader
    public let name: String

    public init(shader: Shader, name: String) {
        precondition(!name.isEmpty, "Shader function name must not be empty")

        self.shader = shader
        self.name = name
    }
}
