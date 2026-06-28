import Swift

public enum Material: Equatable, Sendable {
    case sprite(TextureID, sourceRect: Rect?)
    case shape(AnyShape)

    public static func shape<S: Shape>(_ shape: S) -> Material {
        .shape(AnyShape(shape))
    }
}
