import JavaScriptKit
import PixlPlatform

final class WasmMouse {
    private let mouse: Mouse
    private let canvas: JSObject
    private var pointerMove: JSClosure?
    private var pointerDown: JSClosure?
    private var pointerUp: JSClosure?
    private var pointerCancel: JSClosure?
    private var wheel: JSClosure?
    private var focusChanged: JSClosure?

    init(mouse: Mouse, canvas: JSObject) {
        self.mouse = mouse
        self.canvas = canvas
        install()
    }

    deinit {
        if let pointerMove { _ = canvas.removeEventListener!("pointermove", pointerMove) }
        if let pointerDown { _ = canvas.removeEventListener!("pointerdown", pointerDown) }
        if let pointerUp { _ = canvas.removeEventListener!("pointerup", pointerUp) }
        if let pointerCancel { _ = canvas.removeEventListener!("pointercancel", pointerCancel) }
        if let wheel { _ = canvas.removeEventListener!("wheel", wheel) }
        if let focusChanged {
            let window = JSObject.global.window
            _ = window.removeEventListener("focus", focusChanged)
            _ = window.removeEventListener("blur", focusChanged)
        }
    }

    private func install() {
        pointerMove = JSClosure { [weak self] arguments in
            self?.handleMotion(arguments.first?.object)
            return .undefined
        }
        pointerDown = JSClosure { [weak self] arguments in
            self?.handleButton(arguments.first?.object, phase: .down)
            return .undefined
        }
        pointerUp = JSClosure { [weak self] arguments in
            self?.handleButton(arguments.first?.object, phase: .up)
            return .undefined
        }
        pointerCancel = JSClosure { [weak self] arguments in
            self?.handleButton(arguments.first?.object, phase: .up)
            return .undefined
        }
        wheel = JSClosure { [weak self] arguments in
            self?.handleScroll(arguments.first?.object)
            return .undefined
        }
        focusChanged = JSClosure { [weak self] _ in
            self?.updateFocus()
            return .undefined
        }

        _ = canvas.addEventListener!("pointermove", pointerMove!)
        _ = canvas.addEventListener!("pointerdown", pointerDown!)
        _ = canvas.addEventListener!("pointerup", pointerUp!)
        _ = canvas.addEventListener!("pointercancel", pointerCancel!)
        _ = canvas.addEventListener!("wheel", wheel!)
        let window = JSObject.global.window
        _ = window.addEventListener("focus", focusChanged!)
        _ = window.addEventListener("blur", focusChanged!)
        updateFocus()
    }

    private func handleMotion(_ event: JSObject?) {
        guard let event, event.pointerType.string == "mouse" else { return }
        if let values = event.getCoalescedEvents!().object {
            let count = Int(values.length.number ?? 0)
            if count > 0 {
                for index in 0..<count {
                    if let sample = values[index].object { appendMotion(sample) }
                }
                return
            }
        }
        appendMotion(event)
    }

    private func appendMotion(_ event: JSObject) {
        let scale = displayScale
        mouse.handle(.init(
            timestamp: (event.timeStamp.number ?? 0) / 1_000,
            rawLocation: location(event),
            rawTranslation: SIMD2(
                Float(event.movementX.number ?? 0) * scale,
                -Float(event.movementY.number ?? 0) * scale
            )
        ))
    }

    private func handleButton(_ event: JSObject?, phase: Mouse.Button.Phase) {
        guard let event, event.pointerType.string == "mouse" else { return }
        _ = event.preventDefault!()
        if phase == .down, let pointerID = event.pointerId.number {
            _ = canvas.setPointerCapture!(pointerID)
        }
        mouse.handle(.init(
            timestamp: (event.timeStamp.number ?? 0) / 1_000,
            button: button(Int(event.button.number ?? 0)),
            phase: phase,
            rawLocation: location(event),
            modifiers: modifiers(event)
        ))
    }

    private func handleScroll(_ event: JSObject?) {
        guard let event else { return }
        _ = event.preventDefault!()
        let mode = Int(event.deltaMode.number ?? 0)
        let unit: Mouse.ScrollUnit = mode == 1 ? .line : (mode == 2 ? .page : .pixel)
        let scale: Float = unit == .pixel ? displayScale : 1
        mouse.handle(.init(
            timestamp: (event.timeStamp.number ?? 0) / 1_000,
            rawLocation: location(event),
            translation: SIMD2(
                Float(event.deltaX.number ?? 0) * scale,
                -Float(event.deltaY.number ?? 0) * scale
            ),
            unit: unit
        ))
    }

    private func location(_ event: JSObject) -> SIMD2<Float> {
        let bounds = canvas.getBoundingClientRect!().object!
        let x = Float((event.clientX.number ?? 0) - (bounds.left.number ?? 0))
        let y = Float((bounds.bottom.number ?? 0) - (event.clientY.number ?? 0))
        return SIMD2(x * displayScale, y * displayScale)
    }

    private var displayScale: Float {
        Float(JSObject.global.window.devicePixelRatio.number ?? 1)
    }

    private func button(_ browserButton: Int) -> Mouse.Button {
        switch browserButton {
        case 0: .primary
        case 1: .tertiary
        case 2: .secondary
        default: .init(rawValue: UInt8(clamping: browserButton))
        }
    }

    private func modifiers(_ event: JSObject) -> Key.Modifiers {
        var result: Key.Modifiers = []
        if event.metaKey.boolean == true { result.insert(.command) }
        if event.ctrlKey.boolean == true { result.insert(.control) }
        if event.altKey.boolean == true { result.insert(.option) }
        if event.shiftKey.boolean == true { result.insert(.shift) }
        return result
    }

    private func updateFocus() {
        mouse.focus(
            JSObject.global.document.hasFocus().boolean == true,
            timestamp: JSObject.global.performance.now().number.map { $0 / 1_000 } ?? 0
        )
    }
}
