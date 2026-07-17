import PixlPlatform

/// Runtime services available while a game constructs its persistent state.
public final class GameContext {
    public let platform: any Platform
    public let drawableFormat: PixelFormat
    public let audio: Audio
    public let assets: Assets


    init(
        platform: any Platform,
        format: PixelFormat
    ) {
        self.platform = platform
        self.drawableFormat = format
        audio = Audio(device: platform.audioDevice)
        assets = Assets(
            device: platform.device,
            audioDevice: platform.audioDevice,
            source: platform.assetSource
        )
    }
}
