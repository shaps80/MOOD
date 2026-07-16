import Swift

public protocol PlatformGame {
    static var gameSettings: GameSettings { get }
    static var renderSettings: RenderSettings { get }
    static var assetPath: String? { get }

    init(platform: any Platform) throws

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame
    ) throws
}

public extension PlatformGame {
    static var assetPath: String? { nil }
}

public protocol Platform: AnyObject {
    var device: any Device { get }
    var assetSource: (any AssetSource)? { get }

    func drawable() -> Drawable?

    func present(
        _ frame: borrowing Frame,
        to drawable: consuming Drawable
    ) throws(PlatformError)

    func discard(_ drawable: consuming Drawable)
}

public extension Platform {
    var assetSource: (any AssetSource)? { nil }
}

public enum PlatformError: Error, Hashable, Sendable {
    case invalidDrawable
    case queue(QueueError)
}
