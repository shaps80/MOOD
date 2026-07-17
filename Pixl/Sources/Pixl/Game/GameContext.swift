import PixlPlatform

/// Runtime services available while a game constructs its persistent state.
public final class GameContext {
    private let storedPlatform: (any Platform)?
    public let renderSettings: RenderSettings
    public let audio: Audio
    public let assets: Assets

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
        audio = Audio(device: platform.audioDevice)
        assets = Assets(
            device: platform.device,
            audioDevice: platform.audioDevice,
            source: platform.assetSource
        )
    }

    private init() {
        storedPlatform = nil
        renderSettings = .default
        audio = Audio(device: nil)
        assets = Assets(device: nil, audioDevice: nil, source: nil)
    }

    static var testing: GameContext { .init() }
}
