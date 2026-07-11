import MetalKit
import PixlPlatform

final class MetalPlatform: Platform {
    private let metalDevice: MetalDevice
    private let queue: MetalQueue
    private let view: MTKView
    private let drawables = ResourcePool<any CAMetalDrawable>(capacity: 3)

    var device: any Device { metalDevice }

    init(view: MTKView) {
        guard let nativeDevice = view.device else {
            fatalError("MTKView requires an MTLDevice")
        }

        let metalDevice = MetalDevice(device: nativeDevice, textureCapacity: 256)
        guard let commandQueue = nativeDevice.makeCommandQueue() else {
            fatalError("Metal command queue creation failed")
        }

        self.metalDevice = metalDevice
        queue = MetalQueue(queue: commandQueue, textures: metalDevice.textures)
        self.view = view
    }

    func drawable() -> Drawable? {
        guard let drawable = view.currentDrawable,
              let format = drawable.texture.pixelFormat.pixlPixelFormat,
              let textureID = metalDevice.textures.insert(drawable.texture)
        else {
            return nil
        }

        guard let drawableID = drawables.insert(drawable) else {
            _ = metalDevice.textures.remove(textureID)
            return nil
        }

        let texture = Texture(
            id: textureID,
            descriptor: TextureDescriptor(
                size: TextureSize(
                    width: drawable.texture.width,
                    height: drawable.texture.height
                ),
                format: format,
                usage: [.renderAttachment]
            )
        )

        return Drawable(texture: texture, id: drawableID)
    }

    func present(
        _ frame: Frame,
        to drawable: consuming Drawable
    ) throws(PlatformError) {
        let drawableID = drawable.id
        let textureID = drawable.texture.id

        defer {
            release(drawableID: drawableID, textureID: textureID)
        }

        do {
            guard let _ = try drawables.withValue(for: drawableID, { metalDrawable in
                try queue.submit(frame, presenting: metalDrawable.pointee)
            }) else {
                throw PlatformError.invalidDrawable
            }
        } catch let error as QueueError {
            throw PlatformError.queue(error)
        } catch {
            throw PlatformError.invalidDrawable
        }
    }

    func discard(_ drawable: consuming Drawable) {
        release(drawableID: drawable.id, textureID: drawable.texture.id)
    }

    private func release(drawableID: ResourceID, textureID: ResourceID) {
        _ = drawables.remove(drawableID)
        _ = metalDevice.textures.remove(textureID)
    }
}
