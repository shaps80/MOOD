import JavaScriptKit
import PixlPlatform

final class WasmKeyboard {
    private let keyboard: Keyboard
    private let canvas: JSObject
    private var keyDown: JSClosure?
    private var keyUp: JSClosure?
    private var focusChanged: JSClosure?
    private var pointerDown: JSClosure?

    init(keyboard: Keyboard, canvas: JSObject) {
        self.keyboard = keyboard
        self.canvas = canvas
        install()
    }

    deinit {
        let window = JSObject.global.window
        if let keyDown { _ = window.removeEventListener("keydown", keyDown) }
        if let keyUp { _ = window.removeEventListener("keyup", keyUp) }
        if let focusChanged {
            _ = window.removeEventListener("focus", focusChanged)
            _ = window.removeEventListener("blur", focusChanged)
        }
        if let pointerDown { _ = canvas.removeEventListener!("pointerdown", pointerDown) }
    }

    private func install() {
        canvas.tabIndex = .number(0)

        keyDown = JSClosure { [weak self] arguments in
            self?.handle(arguments.first, phase: .down)
            return .undefined
        }
        keyUp = JSClosure { [weak self] arguments in
            self?.handle(arguments.first, phase: .up)
            return .undefined
        }
        focusChanged = JSClosure { [weak self] _ in
            self?.updateFocus()
            return .undefined
        }
        pointerDown = JSClosure { [weak self] _ in
            self?.focusCanvas()
            return .undefined
        }

        let window = JSObject.global.window
        _ = window.addEventListener("keydown", keyDown!)
        _ = window.addEventListener("keyup", keyUp!)
        _ = window.addEventListener("focus", focusChanged!)
        _ = window.addEventListener("blur", focusChanged!)
        _ = canvas.addEventListener!("pointerdown", pointerDown!)

        focusCanvas()
        updateFocus()
    }

    private func handle(_ value: JSValue?, phase: Key.Phase) {
        guard let event = value?.object,
              let code = event.code.string,
              let key = Key(browserCode: code)
        else { return }

        _ = event.preventDefault!()
        keyboard.handle(.init(
            key: key,
            phase: phase,
            modifiers: modifiers(for: event),
            isRepeat: phase == .down && event.repeat.boolean == true
        ))
    }

    private func modifiers(for event: JSObject) -> Key.Modifiers {
        var modifiers: Key.Modifiers = []
        if event.metaKey.boolean == true { modifiers.insert(.command) }
        if event.ctrlKey.boolean == true { modifiers.insert(.control) }
        if event.altKey.boolean == true { modifiers.insert(.option) }
        if event.shiftKey.boolean == true { modifiers.insert(.shift) }
        return modifiers
    }

    private func focusCanvas() {
        _ = canvas.focus!()
    }

    private func updateFocus() {
        let focused = JSObject.global.document.hasFocus().boolean == true
        keyboard.focus(focused)
        if focused { focusCanvas() }
    }
}

private extension Key {
    init?(browserCode code: String) {
        switch code {
        case "KeyA": self = .a; case "KeyB": self = .b
        case "KeyC": self = .c; case "KeyD": self = .d
        case "KeyE": self = .e; case "KeyF": self = .f
        case "KeyG": self = .g; case "KeyH": self = .h
        case "KeyI": self = .i; case "KeyJ": self = .j
        case "KeyK": self = .k; case "KeyL": self = .l
        case "KeyM": self = .m; case "KeyN": self = .n
        case "KeyO": self = .o; case "KeyP": self = .p
        case "KeyQ": self = .q; case "KeyR": self = .r
        case "KeyS": self = .s; case "KeyT": self = .t
        case "KeyU": self = .u; case "KeyV": self = .v
        case "KeyW": self = .w; case "KeyX": self = .x
        case "KeyY": self = .y; case "KeyZ": self = .z
        case "Digit0": self = .zero; case "Digit1": self = .one
        case "Digit2": self = .two; case "Digit3": self = .three
        case "Digit4": self = .four; case "Digit5": self = .five
        case "Digit6": self = .six; case "Digit7": self = .seven
        case "Digit8": self = .eight; case "Digit9": self = .nine
        case "Backquote": self = .backquote; case "Minus": self = .minus
        case "Equal": self = .equal; case "BracketLeft": self = .bracketLeft
        case "BracketRight": self = .bracketRight; case "Backslash": self = .backslash
        case "Semicolon": self = .semicolon; case "Quote": self = .quote
        case "Comma": self = .comma; case "Period": self = .period
        case "Slash": self = .slash; case "Space": self = .space
        case "Tab": self = .tab; case "Enter": self = .enter
        case "Backspace": self = .backspace; case "Escape": self = .escape
        case "ArrowLeft": self = .arrowLeft; case "ArrowRight": self = .arrowRight
        case "ArrowUp": self = .arrowUp; case "ArrowDown": self = .arrowDown
        case "Insert": self = .insert; case "Delete": self = .delete
        case "Home": self = .home; case "End": self = .end
        case "PageUp": self = .pageUp; case "PageDown": self = .pageDown
        case "CapsLock": self = .capsLock; case "NumLock": self = .numLock
        case "ScrollLock": self = .scrollLock; case "PrintScreen": self = .printScreen
        case "Pause": self = .pause; case "ShiftLeft": self = .leftShift
        case "ShiftRight": self = .rightShift; case "ControlLeft": self = .leftControl
        case "ControlRight": self = .rightControl; case "AltLeft": self = .leftOption
        case "AltRight": self = .rightOption; case "MetaLeft": self = .leftCommand
        case "MetaRight": self = .rightCommand; case "ContextMenu": self = .contextMenu
        case "F1": self = .f1; case "F2": self = .f2; case "F3": self = .f3
        case "F4": self = .f4; case "F5": self = .f5; case "F6": self = .f6
        case "F7": self = .f7; case "F8": self = .f8; case "F9": self = .f9
        case "F10": self = .f10; case "F11": self = .f11; case "F12": self = .f12
        case "F13": self = .f13; case "F14": self = .f14; case "F15": self = .f15
        case "F16": self = .f16; case "F17": self = .f17; case "F18": self = .f18
        case "F19": self = .f19; case "F20": self = .f20
        case "Numpad0": self = .numpadZero; case "Numpad1": self = .numpadOne
        case "Numpad2": self = .numpadTwo; case "Numpad3": self = .numpadThree
        case "Numpad4": self = .numpadFour; case "Numpad5": self = .numpadFive
        case "Numpad6": self = .numpadSix; case "Numpad7": self = .numpadSeven
        case "Numpad8": self = .numpadEight; case "Numpad9": self = .numpadNine
        case "NumpadDecimal": self = .numpadDecimal; case "NumpadAdd": self = .numpadAdd
        case "NumpadSubtract": self = .numpadSubtract
        case "NumpadMultiply": self = .numpadMultiply
        case "NumpadDivide": self = .numpadDivide
        case "NumpadEnter": self = .numpadEnter
        case "NumpadEqual": self = .numpadEqual
        case "NumpadComma": self = .numpadComma
        case "Help": self = .help
        default: return nil
        }
    }
}
