@preconcurrency import GameController
import Pixl
import Swift

@MainActor
final class GamepadInput {
    private let axisDeadZone = 0.12

    init() {
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    deinit {
        GCController.stopWirelessControllerDiscovery()
    }

    var state: Input {
        var state = Input()

        for controller in GCController.controllers() {
            state = state.combined(with: stateForController(controller))
        }

        return state
    }

    private func stateForController(_ controller: GCController) -> Input {
        if let gamepad = controller.extendedGamepad {
            return stateForExtendedGamepad(gamepad)
        }

        if let gamepad = controller.microGamepad {
            return stateForMicroGamepad(gamepad)
        }

        return Input()
    }

    private func stateForExtendedGamepad(_ gamepad: GCExtendedGamepad) -> Input {
        let horizontal = axisValue(
            negative: gamepad.dpad.left.isPressed,
            positive: gamepad.dpad.right.isPressed,
            analog: Double(gamepad.leftThumbstick.xAxis.value)
        )
        let vertical = axisValue(
            negative: gamepad.dpad.up.isPressed,
            positive: gamepad.dpad.down.isPressed,
            analog: -Double(gamepad.leftThumbstick.yAxis.value)
        )

        return Input(
            horizontal: horizontal,
            vertical: vertical,
            jump: gamepad.buttonA.isPressed,
            reset: gamepad.buttonMenu.isPressed
        )
    }

    private func stateForMicroGamepad(_ gamepad: GCMicroGamepad) -> Input {
        let horizontal = axisValue(
            negative: gamepad.dpad.left.isPressed,
            positive: gamepad.dpad.right.isPressed,
            analog: Double(gamepad.dpad.xAxis.value)
        )
        let vertical = axisValue(
            negative: gamepad.dpad.up.isPressed,
            positive: gamepad.dpad.down.isPressed,
            analog: -Double(gamepad.dpad.yAxis.value)
        )

        return Input(
            horizontal: horizontal,
            vertical: vertical,
            jump: gamepad.buttonA.isPressed,
            reset: gamepad.buttonMenu.isPressed
        )
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
