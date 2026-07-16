import Swift

public protocol PlatformGame {
    static var gameSettings: GameSettings { get }
    static var renderSettings: RenderSettings { get }

    init(platform: any Platform) throws

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
