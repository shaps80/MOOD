import Swift

public protocol PlatformGame {
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame
    ) throws
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
