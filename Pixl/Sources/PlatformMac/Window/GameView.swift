@preconcurrency import AppKit
@preconcurrency import MetalKit
import Swift

final class GameView: MTKView {
    private let keyboardInput: KeyboardInput

    init(
        frame frameRect: NSRect,
        device: MTLDevice,
        keyboardInput: KeyboardInput
    ) {
        self.keyboardInput = keyboardInput

        super.init(frame: frameRect, device: device)

        autoResizeDrawable = true
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        colorPixelFormat = .bgra8Unorm
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

    override func keyDown(with event: NSEvent) {
        guard !keyboardInput.handleKeyEvent(event, isPressed: true) else {
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        guard !keyboardInput.handleKeyEvent(event, isPressed: false) else {
            return
        }

        super.keyUp(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
