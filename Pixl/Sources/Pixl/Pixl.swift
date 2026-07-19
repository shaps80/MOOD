@_exported import PixlGraphics
import PixlPlatform

public typealias RenderTarget = PixlPlatform.RenderTarget
public typealias Bus = PixlPlatform.Bus
public typealias Playback = PixlPlatform.Playback
public typealias GamePhase = PixlPlatform.GamePhase
public typealias Platform = PixlPlatform.Platform
public typealias GameSettings = PixlPlatform.GameSettings
public typealias Frame = PixlPlatform.Frame

#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif
#if canImport(PixlWasmPlatform)
import PixlWasmPlatform
#endif

public extension Game {
    static var audioSettings: AudioSettings {
        .default
    }

    static var renderSettings: RenderSettings {
        .default
    }

    static var loopSettings: LoopSettings {
        .default
    }

    mutating func didEnter(_ phase: GamePhase, context: GameContext) { }
    mutating func fixedUpdate(
        _ time: FixedTime,
        context: GameContext
    ) { }
    mutating func update(
        _ time: UpdateTime,
        context: GameContext
    ) { }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime,
        context: GameContext
    ) throws {}

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
