import Pixl
import JavaScriptKit
import Swift

extension Renderer {
    func loadSpriteTextures(_ spriteAssets: [SpriteAsset]) {
        for spriteAsset in Set(spriteAssets) {
            loadSpriteTexture(spriteAsset)
        }
    }

    private func loadSpriteTexture(_ spriteAsset: SpriteAsset) {
        guard device != nil else { return }

        let image = JSObject.global.Image.object!.new()
        let loadClosure = JSClosure { [weak self] _ in
            guard let self, let device = self.device else { return .undefined }
            let width = image.width.number ?? 0
            let height = image.height.number ?? 0
            let texture = device.createTexture!(object(
                "label", spriteAsset.path,
                "size", object("width", width, "height", height, "depthOrArrayLayers", 1),
                "format", "rgba8unorm",
                "usage", gpuTextureUsageTextureBinding | gpuTextureUsageCopyDst | gpuTextureUsageRenderAttachment
            )).object!
            _ = device.queue.copyExternalImageToTexture(
                object("source", image), object("texture", texture),
                object("width", width, "height", height, "depthOrArrayLayers", 1)
            )
            self.spriteTextures[spriteAsset.id] = texture
            self.spriteTextureSizes[spriteAsset.id] = Vec2(
                x: width,
                y: height
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
}
