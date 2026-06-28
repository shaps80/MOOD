import Swift

public enum Material: Equatable, Sendable {
    case sprite(TextureID, sourceRect: Rect?)
    case shape(AnyShape, Vec2)

    public static func shape<S: Shape>(_ shape: S, size: Vec2) -> Material {
        .shape(AnyShape(shape), size)
    }
}

extension Material {
    var naturalSize: Vec2? {
        switch self {
        case .sprite(_, let sourceRect):
            sourceRect?.size
        case .shape(_, let size):
            size
        }
    }
}
