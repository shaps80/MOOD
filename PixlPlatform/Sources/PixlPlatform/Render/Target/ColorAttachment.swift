import Swift

/// One colour target and its behaviour at render-pass boundaries.
public struct ColorAttachment: Sendable, Hashable {
    /// Texture subresource written by the pass.
    public var target: RenderTarget
    /// Operation performed when the pass begins.
    public var loadAction: LoadAction
    /// Operation performed when the pass ends.
    public var storeAction: StoreAction

    /// Creates a colour attachment.
    /// - Parameters:
    ///   - target: Texture subresource written by the pass.
    ///   - loadAction: Operation performed when the pass begins.
    ///   - storeAction: Operation performed when the pass ends.
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

/// How a render pass initializes a colour attachment.
public enum LoadAction: Sendable, Hashable {
    /// Preserves the attachment's existing contents.
    case load
    /// Fills the attachment with a colour before drawing.
    case clear(Color)
    /// Leaves initial attachment contents undefined.
    case discard
}

/// Whether a render pass preserves its final colour contents.
public enum StoreAction: Sendable, Hashable {
    /// Preserves final contents for presentation or later use.
    case store
    /// Allows the backend to discard final contents.
    case discard
}
