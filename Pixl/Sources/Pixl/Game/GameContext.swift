import PixlPlatform

/// Stable runtime services and controls supplied throughout the game lifecycle.
public final class GameContext {
    public let platform: any Platform
    public let drawableFormat: PixelFormat
    public let audio: Audio
    public let assets: Assets
    public let keyboard: Keyboard
    public let gamepads: Gamepads
    public let inputs: Input.Map

    /// Nonnegative simulation-time multiplier. Zero pauses scaled simulation.
    public var timeScale: Double = 1 {
        didSet {
            precondition(
                timeScale.isFinite && timeScale >= 0,
                "Time scale must be finite and nonnegative"
            )
        }
    }

    init(
        platform: any Platform,
        format: PixelFormat
    ) {
        self.platform = platform
        self.drawableFormat = format
        keyboard = platform.keyboard
        gamepads = platform.gamepads
        inputs = Input.Map(keyboard: keyboard, gamepads: gamepads)
        audio = Audio(device: platform.audioDevice)
        assets = Assets(
            device: platform.device,
            audioDevice: platform.audioDevice,
            source: platform.assetSource
        )
    }
}
