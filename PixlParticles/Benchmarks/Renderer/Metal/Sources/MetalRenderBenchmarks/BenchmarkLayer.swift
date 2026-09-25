import Metal
import QuartzCore

/// A real private render target, independent of display visibility or sleep.
final class BenchmarkLayer: CAMetalLayer {
    var offscreen: BenchmarkDrawable
    init(device: any MTLDevice, width: Int, height: Int) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
            width: width, height: height, mipmapped: false)
        descriptor.storageMode = .private
        descriptor.usage = .renderTarget
        offscreen = BenchmarkDrawable(texture: device.makeTexture(descriptor: descriptor)!)
        super.init()
        self.device = device
    }
    func resize(width: Int, height: Int) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
            width: width, height: height, mipmapped: false)
        descriptor.storageMode = .private
        descriptor.usage = .renderTarget
        offscreen = BenchmarkDrawable(texture: device!.makeTexture(descriptor: descriptor)!)
    }
    override init(layer: Any) { fatalError("Not a display layer") }
    required init?(coder: NSCoder) { fatalError("Not archived") }
    override func nextDrawable() -> (any CAMetalDrawable)? { offscreen }
}

final class BenchmarkDrawable: NSObject, CAMetalDrawable {
    let texture: any MTLTexture
    var layer: CAMetalLayer { fatalError("Offscreen drawable") }
    let drawableID: Int = 0
    let presentedTime: CFTimeInterval = 0
    init(texture: any MTLTexture) { self.texture = texture }
    func present() {}
    func present(at presentationTime: CFTimeInterval) {}
    func present(afterMinimumDuration duration: CFTimeInterval) {}
    func addPresentedHandler(_ block: @escaping MTLDrawablePresentedHandler) {}
}
