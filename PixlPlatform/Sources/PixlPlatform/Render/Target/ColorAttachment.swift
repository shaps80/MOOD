import Swift

public struct ColorAttachment: Sendable, Hashable {
    public var target: RenderTarget
    public var loadAction: LoadAction
    public var storeAction: StoreAction

    public init(
        target: RenderTarget,
        loadAction: LoadAction,
        storeAction: StoreAction = .store
    ) {
        self.target = target
        self.loadAction = loadAction
        self.storeAction = storeAction
    }
}

public enum LoadAction: Sendable, Hashable {
    case load
    case clear(Color)
    case discard
}

public enum StoreAction: Sendable, Hashable {
    case store
    case discard
}

public struct Color: Sendable, Hashable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white: Self = .init(red: 1, green: 1, blue: 1)
    public static let black: Self = .init(red: 0, green: 0, blue: 0)
    public static let red: Self = .init(red: 1, green: 0, blue: 0)
}
