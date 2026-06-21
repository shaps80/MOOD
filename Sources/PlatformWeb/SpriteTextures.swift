import GameCore
import JavaScriptKit
import Swift

extension Runtime {
    func loadSpriteTextures() {
        for spriteAsset in Set(game.spriteAssets) {
            loadSpriteTexture(spriteAsset)
        }
    }

    private func loadSpriteTexture(_ spriteAsset: SpriteAsset) {
        guard let gl else { return }

        let image = JSObject.global.Image.object!.new()
        let texture = gl.createTexture!()

        let loadClosure = JSClosure { [weak self] _ in
            guard let self, let gl = self.gl else { return .undefined }

            _ = gl.bindTexture!(gl.TEXTURE_2D, texture)
            self.configureTextureParameters(gl)
            _ = gl.texImage2D!(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image)
            self.spriteTextures[spriteAsset.id] = texture
            self.spriteTextureSizes[spriteAsset.id] = Vec2(
                x: image.width.number ?? 0,
                y: image.height.number ?? 0
            )

            return .undefined
        }

        let errorClosure = JSClosure { _ in
            _ = JSObject.global.console.error("Unable to load sprite asset '\(spriteAsset.path)'")
            return .undefined
        }

        image.onload = .object(loadClosure)
        image.onerror = .object(errorClosure)
        image.src = .string(spriteAsset.path)

        spriteImages[spriteAsset.id] = image
        spriteLoadClosures[spriteAsset.id] = loadClosure
        spriteErrorClosures[spriteAsset.id] = errorClosure
    }

    private func configureTextureParameters(_ gl: JSObject) {
        let filter: JSValue

        switch game.interpolationMode {
        case .linear:
            filter = gl.LINEAR
        case .nearest:
            filter = gl.NEAREST
        }

        _ = gl.texParameteri!(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter)
        _ = gl.texParameteri!(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter)
        _ = gl.texParameteri!(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        _ = gl.texParameteri!(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
    }
}
