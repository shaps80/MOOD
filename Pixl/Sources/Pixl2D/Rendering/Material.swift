/// Describes how renderable content is shaded.
///
/// Pixl currently provides only unlit shading. Future materials may support
/// lighting, normal maps, emission, and custom shader parameters.
public struct Material: Equatable, Sendable {
    /// The built-in material that ignores lighting and emits its paint directly.
    public static let unlit = Self()

    public init() {}
}
