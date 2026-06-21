import GameCore
import JavaScriptKit
import Swift

final class GamepadInput {
    private let axisDeadZone = 0.35
    private var wasJumpPressed = false

    var state: InputState {
        guard let gamepads = JSObject.global.navigator.getGamepads().array else {
            return InputState()
        }

        var state = InputState()

        for gamepadValue in gamepads {
            guard let gamepad = gamepadValue.object else { continue }

            state = state.combined(with: stateForGamepad(gamepad))
        }

        logJumpPressIfNeeded(state.jump)

        return state
    }

    private func stateForGamepad(_ gamepad: JSObject) -> InputState {
        let horizontal = axisValue(
            negative: isDPadPressed(.left, gamepad: gamepad),
            positive: isDPadPressed(.right, gamepad: gamepad),
            analog: axis(0, gamepad: gamepad)
        )
        let vertical = axisValue(
            negative: isDPadPressed(.up, gamepad: gamepad),
            positive: isDPadPressed(.down, gamepad: gamepad),
            analog: axis(1, gamepad: gamepad)
        )

        return InputState(
            horizontal: horizontal,
            vertical: vertical,
            jump: isButtonPressed(0, gamepad: gamepad)
        )
    }

    private func axis(_ index: Int, gamepad: JSObject) -> Double {
        guard let axes = gamepad.axes.array,
              axes.indices.contains(index)
        else {
            return 0
        }

        return axes[index].number ?? 0
    }

    private func isButtonPressed(_ index: Int, gamepad: JSObject) -> Bool {
        guard let buttons = gamepad.buttons.array,
              buttons.indices.contains(index)
        else {
            return false
        }

        return buttons[index].pressed.boolean == true
    }

    private func isDPadPressed(_ direction: DPadDirection, gamepad: JSObject) -> Bool {
        isButtonPressed(direction.buttonIndex, gamepad: gamepad)
    }

    private func logJumpPressIfNeeded(_ isJumpPressed: Bool) {
        if isJumpPressed && !wasJumpPressed {
            _ = JSObject.global.console.log("Gamepad jump pressed")
        }

        wasJumpPressed = isJumpPressed
    }

    private func axisValue(negative: Bool, positive: Bool, analog: Double) -> Double {
        if negative && !positive {
            return -1
        }

        if positive && !negative {
            return 1
        }

        guard abs(analog) >= axisDeadZone else {
            return 0
        }

        return analog
    }
}

private enum DPadDirection {
    case up
    case down
    case left
    case right

    var buttonIndex: Int {
        switch self {
        case .up:
            return 12
        case .down:
            return 13
        case .left:
            return 14
        case .right:
            return 15
        }
    }
}
