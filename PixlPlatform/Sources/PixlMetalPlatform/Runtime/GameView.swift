@preconcurrency import AppKit
@preconcurrency import MetalKit
import PixlPlatform

final class GameView: MTKView {
    var keyboard: Keyboard?

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

    override func keyDown(with event: NSEvent) {
        guard let key = Key(macKeyCode: event.keyCode) else {
            super.keyDown(with: event)
            return
        }
        keyboard?.handle(.init(
            key: key,
            phase: .down,
            modifiers: .init(event.modifierFlags),
            isRepeat: event.isARepeat
        ))
    }

    override func keyUp(with event: NSEvent) {
        guard let key = Key(macKeyCode: event.keyCode) else {
            super.keyUp(with: event)
            return
        }
        keyboard?.handle(.init(
            key: key,
            phase: .up,
            modifiers: .init(event.modifierFlags)
        ))
    }

    override func flagsChanged(with event: NSEvent) {
        guard let keyboard, let key = Key(macKeyCode: event.keyCode) else {
            super.flagsChanged(with: event)
            return
        }
        keyboard.handle(.init(
            key: key,
            phase: keyboard.contains(key) ? .up : .down,
            modifiers: .init(event.modifierFlags)
        ))
    }
}

private extension Key.Modifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
    }
}
