import JavaScriptKit
import PixlPlatform

final class WasmGamepads {
    private let gamepads: Gamepads

    init(gamepads: Gamepads) {
        self.gamepads = gamepads
    }

    func poll() {
        guard let nativeGamepads = JSObject.global.navigator
            .getGamepads().array
        else { return }

        let count = max(nativeGamepads.count, gamepads.slotCount)
        for index in 0..<count {
            guard nativeGamepads.indices.contains(index),
                  let native = nativeGamepads[index].object,
                  native.connected.boolean == true,
                  native.mapping.string == "standard",
                  let gamepad = gamepads.gamepad(
                    at: index,
                    name: native.id.string ?? "Gamepad"
                  )
            else {
                gamepads.disconnect(at: index)
                continue
            }

            update(gamepad, from: native)
        }
    }

    private func update(_ gamepad: Gamepad, from native: JSObject) {
        guard let buttons = native.buttons.array,
              let axes = native.axes.array
        else { return }

        update(gamepad, .south, index: 0, buttons: buttons)
        update(gamepad, .east, index: 1, buttons: buttons)
        update(gamepad, .west, index: 2, buttons: buttons)
        update(gamepad, .north, index: 3, buttons: buttons)
        update(gamepad, .leftShoulder, index: 4, buttons: buttons)
        update(gamepad, .rightShoulder, index: 5, buttons: buttons)
        update(gamepad, .leftTrigger, index: 6, buttons: buttons)
        update(gamepad, .rightTrigger, index: 7, buttons: buttons)
        update(gamepad, .options, index: 8, buttons: buttons)
        update(gamepad, .menu, index: 9, buttons: buttons)
        update(gamepad, .leftStick, index: 10, buttons: buttons)
        update(gamepad, .rightStick, index: 11, buttons: buttons)
        update(gamepad, .up, index: 12, buttons: buttons)
        update(gamepad, .down, index: 13, buttons: buttons)
        update(gamepad, .left, index: 14, buttons: buttons)
        update(gamepad, .right, index: 15, buttons: buttons)

        gamepad.updateSticks(
            left: .init(axis(0, axes), -axis(1, axes)),
            right: .init(axis(2, axes), -axis(3, axes))
        )
    }

    private func update(
        _ gamepad: Gamepad,
        _ button: Gamepad.Button,
        index: Int,
        buttons: JSArray
    ) {
        guard buttons.indices.contains(index),
              let native = buttons[index].object
        else {
            gamepad.update(button, value: 0, pressed: false)
            return
        }
        gamepad.update(
            button,
            value: Float(native.value.number ?? 0),
            pressed: native.pressed.boolean == true
        )
    }

    private func axis(_ index: Int, _ axes: JSArray) -> Float {
        guard axes.indices.contains(index) else { return 0 }
        return Float(axes[index].number ?? 0)
    }
}
