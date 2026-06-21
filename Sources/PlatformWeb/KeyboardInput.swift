import GameCore
import JavaScriptKit
import Swift

final class KeyboardInput {
    private var pressedKeys = Set<String>()
    private var keyDownClosure: JSClosure?
    private var keyUpClosure: JSClosure?
    private var blurClosure: JSClosure?

    var state: InputState {
        InputState(
            horizontal: horizontalAxis,
            vertical: verticalAxis,
            jump: isPressed("Space")
        )
    }

    func startListening() {
        let window = JSObject.global

        keyDownClosure = JSClosure { [weak self] arguments in
            self?.handleKeyEvent(arguments.first, isPressed: true)
            return .undefined
        }

        keyUpClosure = JSClosure { [weak self] arguments in
            self?.handleKeyEvent(arguments.first, isPressed: false)
            return .undefined
        }

        blurClosure = JSClosure { [weak self] _ in
            self?.pressedKeys.removeAll()
            return .undefined
        }

        _ = window.addEventListener!("keydown", keyDownClosure)
        _ = window.addEventListener!("keyup", keyUpClosure)
        _ = window.addEventListener!("blur", blurClosure)
    }

    private var horizontalAxis: Double {
        let left = isPressed("ArrowLeft") || isPressed("KeyA")
        let right = isPressed("ArrowRight") || isPressed("KeyD")

        switch (left, right) {
        case (true, false):
            return -1
        case (false, true):
            return 1
        default:
            return 0
        }
    }

    private var verticalAxis: Double {
        let up = isPressed("ArrowUp") || isPressed("KeyW")
        let down = isPressed("ArrowDown") || isPressed("KeyS")

        switch (up, down) {
        case (true, false):
            return -1
        case (false, true):
            return 1
        default:
            return 0
        }
    }

    private func handleKeyEvent(_ eventValue: JSValue?, isPressed: Bool) {
        guard let event = eventValue?.object,
              let code = event.code.string,
              isControlKey(code)
        else {
            return
        }

        _ = event.preventDefault!()

        if isPressed {
            logJumpPressIfNeeded(code)
            pressedKeys.insert(code)
        } else {
            pressedKeys.remove(code)
        }
    }

    private func logJumpPressIfNeeded(_ code: String) {
        if code == "Space" && !pressedKeys.contains(code) {
            _ = JSObject.global.console.log("Keyboard jump pressed")
        }
    }

    private func isPressed(_ code: String) -> Bool {
        pressedKeys.contains(code)
    }

    private func isControlKey(_ code: String) -> Bool {
        switch code {
        case "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight",
             "KeyW", "KeyA", "KeyS", "KeyD",
             "Space":
            return true
        default:
            return false
        }
    }
}
