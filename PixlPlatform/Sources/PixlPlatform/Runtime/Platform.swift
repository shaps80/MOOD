import Swift

public protocol PlatformGame {
    mutating func setup(on platform: any Platform) throws

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame
    ) throws
}

public extension PlatformGame {
    mutating func setup(on platform: any Platform) throws {}
}

public protocol Platform: AnyObject {
    var device: any Device { get }

    func drawable() -> Drawable?

    func present(
        _ frame: borrowing Frame,
        to drawable: consuming Drawable
    ) throws(PlatformError)

    func discard(_ drawable: consuming Drawable)
}

public enum PlatformError: Error, Hashable, Sendable {
    case invalidDrawable
    case queue(QueueError)
}
