import Swift

public protocol PlatformGame {
    @MainActor
    func render(on platform: any Platform) throws
}

@MainActor
public protocol Platform: AnyObject {
    var device: any Device { get }

    func drawable() -> Drawable?

    func present(
        _ frame: Frame,
        to drawable: consuming Drawable
    ) throws(PlatformError)
}

public enum PlatformError: Error, Hashable, Sendable {
    case invalidDrawable
    case queue(QueueError)
}
