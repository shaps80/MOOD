import Swift

public enum Material: Equatable, Sendable {
    case color(Color)
    case sprite(TextureID, sourceRect: Rect?)
}
