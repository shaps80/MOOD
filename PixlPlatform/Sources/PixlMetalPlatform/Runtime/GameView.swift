@preconcurrency import AppKit
@preconcurrency import MetalKit
import PixlPlatform

final class GameView: MTKView {
    var keyboard: Keyboard?
    var mouse: Mouse?

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

    override func mouseMoved(with event: NSEvent) { handleMotion(event) }
    override func mouseDragged(with event: NSEvent) { handleMotion(event) }
    override func rightMouseDragged(with event: NSEvent) { handleMotion(event) }
    override func otherMouseDragged(with event: NSEvent) { handleMotion(event) }

    override func mouseDown(with event: NSEvent) { handleButton(event, phase: .down) }
    override func mouseUp(with event: NSEvent) { handleButton(event, phase: .up) }
    override func rightMouseDown(with event: NSEvent) { handleButton(event, phase: .down) }
    override func rightMouseUp(with event: NSEvent) { handleButton(event, phase: .up) }
    override func otherMouseDown(with event: NSEvent) { handleButton(event, phase: .down) }
    override func otherMouseUp(with event: NSEvent) { handleButton(event, phase: .up) }

    override func scrollWheel(with event: NSEvent) {
        let scale = Float(window?.backingScaleFactor ?? 1)
        let unit: Mouse.ScrollUnit = event.hasPreciseScrollingDeltas ? .pixel : .line
        mouse?.handle(.init(
            timestamp: event.timestamp,
            rawLocation: mouseLocation(event),
            translation: SIMD2(
                Float(event.scrollingDeltaX) * scale,
                Float(event.scrollingDeltaY) * scale
            ),
            unit: unit
        ))
    }

    private func handleMotion(_ event: NSEvent) {
        let scale = Float(window?.backingScaleFactor ?? 1)
        mouse?.handle(.init(
            timestamp: event.timestamp,
            rawLocation: mouseLocation(event),
            rawTranslation: SIMD2(
                Float(event.deltaX) * scale,
                -Float(event.deltaY) * scale
            )
        ))
    }

    private func handleButton(_ event: NSEvent, phase: Mouse.Button.Phase) {
        mouse?.handle(.init(
            timestamp: event.timestamp,
            button: mouseButton(event.buttonNumber),
            phase: phase,
            rawLocation: mouseLocation(event),
            modifiers: mouseModifiers(event.modifierFlags)
        ))
    }

    private func mouseLocation(_ event: NSEvent) -> SIMD2<Float> {
        let point = convert(event.locationInWindow, from: nil)
        let scale = Float(window?.backingScaleFactor ?? 1)
        return SIMD2(Float(point.x) * scale, Float(point.y) * scale)
    }

    private func mouseButton(_ number: Int) -> Mouse.Button {
        switch number {
        case 0: .primary
        case 1: .secondary
        case 2: .tertiary
        default: .init(rawValue: UInt8(clamping: number))
        }
    }

    private func mouseModifiers(_ flags: NSEvent.ModifierFlags) -> Key.Modifiers {
        var modifiers: Key.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        return modifiers
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
