import PixlPlatform

/// Runtime services available while a game constructs its persistent state.
public final class GameContext {
    private let storedPlatform: (any Platform)?
    public let renderSettings: RenderSettings

    public var platform: any Platform {
        guard let storedPlatform else {
            preconditionFailure("The testing game context has no platform")
        }
        return storedPlatform
    }

    init(
        platform: any Platform,
        renderSettings: RenderSettings
    ) {
        storedPlatform = platform
        self.renderSettings = renderSettings
    }

    private init() {
        storedPlatform = nil
        renderSettings = .default
    }

    static var testing: GameContext { .init() }
}
