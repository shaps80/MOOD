@_exported import PixlGraphics
@_exported import PixlInput
import PixlFoundation
import PixlPlatform

/// A renderable texture subresource.
public typealias RenderTarget = PixlPlatform.RenderTarget
/// A flat audio mixing destination.
public typealias Bus = PixlPlatform.Bus
/// Reusable controls for playing one resident sound.
public typealias Playback = PixlPlatform.Playback
/// Coarse platform lifecycle state.
public typealias GamePhase = PixlPlatform.GamePhase
/// Lowest-level portable runtime capability.
public typealias Platform = PixlPlatform.Platform
/// Startup window and presentation preferences.
public typealias GameSettings = PixlPlatform.GameSettings
/// Reusable fixed-capacity render-command recording storage.
public typealias Frame = PixlPlatform.Frame
/// Default retained render-submission and execution queue.
public typealias RenderQueue = PixlFoundation.RenderQueue

#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif
#if canImport(PixlWasmPlatform)
import PixlWasmPlatform
#endif

public extension Game {
    /// Default audio resource capacities.
    static var audioSettings: AudioSettings {
        .default
    }

    /// Default GPU format and fixed capacities.
    static var renderSettings: RenderSettings {
        .default
    }

    /// Default fixed and variable update timing policy.
    static var loopSettings: LoopSettings {
        .default
    }

    /// Default render queue with 10,000 submissions and one view.
    static var renderQueueSettings: RenderQueue.Settings {
        .init()
    }

    /// Default lifecycle callback that performs no work.
    /// - Parameters:
    ///   - phase: Newly entered lifecycle phase.
    ///   - context: Stable runtime services.
    mutating func didEnter(_ phase: GamePhase, context: GameContext) { }
    /// Default fixed-update callback that performs no work.
    /// - Parameters:
    ///   - time: Fixed simulation timing.
    ///   - context: Stable runtime services.
    mutating func fixedUpdate(
        _ time: FixedTime,
        context: GameContext
    ) { }
    /// Default presentation-update callback that performs no work.
    /// - Parameters:
    ///   - time: Presentation timing.
    ///   - context: Stable runtime services.
    mutating func update(
        _ time: UpdateTime,
        context: GameContext
    ) { }

    /// Default render callback that records no commands.
    /// - Parameters:
    ///   - platform: Lowest-level platform capability.
    ///   - output: Presentation render target.
    ///   - frame: Frame recording storage.
    ///   - time: Render timing and prior-frame metrics.
    ///   - context: Stable runtime services.
    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {}

    /// Starts the game using the concrete adapter available to this build.
    @MainActor
    static func main() {
#if canImport(PixlMetalPlatform)
        PixlMetalPlatform.run(GameRuntime<Self>.self)
#elseif canImport(PixlWasmPlatform)
        PixlWasmPlatform.run(GameRuntime<Self>.self)
#else
        fatalError("No Pixl platform is available for this build")
#endif
    }
}
