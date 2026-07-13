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
