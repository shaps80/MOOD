@_exported import PixlPlatform
@_exported import PixlGraphics
@_exported import PixlConcurrency

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

    mutating func fixedUpdate(_ time: FixedTime, lanes: Lanes) { }
    mutating func update(_ time: UpdateTime, lanes: Lanes) { }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
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
