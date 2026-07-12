import JavaScriptKit
import PixlPlatform

final class WasmShaderLibrary: ShaderLibrary {
    let module: JSObject

    init(module: JSObject) {
        self.module = module
    }
}
