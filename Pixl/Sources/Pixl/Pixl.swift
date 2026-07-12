@_exported import PixlPlatform
@_exported import PixlGraphics

#if canImport(PixlMetalPlatform)
import PixlMetalPlatform
#endif
#if canImport(PixlWasmPlatform)
import PixlWasmPlatform
#endif

public extension Game {
    static var defaultShaders: Shader {
        ShaderCatalogue.default
    }

    static var renderSettings: RenderSettings {
        .default
    }

    static var loopSettings: LoopSettings {
        .default
    }

    mutating func fixedUpdate(_ time: FixedTime) {}

    mutating func update(_ time: UpdateTime) { }

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
