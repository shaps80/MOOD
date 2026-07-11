@preconcurrency import AppKit
@preconcurrency import MetalKit
import PixlPlatform

final class GameView: MTKView {
    init(
        frame frameRect: NSRect,
        device: MTLDevice,
        drawableFormat: PixelFormat
    ) {
        super.init(frame: frameRect, device: device)

        autoResizeDrawable = true
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        colorPixelFormat = drawableFormat.metalPixelFormat
        framebufferOnly = true
        isPaused = false
        enableSetNeedsDisplay = false
        presentsWithTransaction = false
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
