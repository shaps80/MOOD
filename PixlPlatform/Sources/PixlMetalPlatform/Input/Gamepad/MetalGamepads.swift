@preconcurrency import GameController
import PixlPlatform
import Swift

@MainActor
final class MetalGamepads: NSObject {
    private let gamepads: Gamepads
    private var controllers: ContiguousArray<GCController?>

    init(gamepads: Gamepads) {
        self.gamepads = gamepads
        controllers = []
        super.init()
        let notifications = NotificationCenter.default
        notifications.addObserver(
            self,
            selector: #selector(controllerDidConnect(_:)),
            name: .GCControllerDidConnect,
            object: nil
        )
        notifications.addObserver(
            self,
            selector: #selector(controllerDidDisconnect(_:)),
            name: .GCControllerDidDisconnect,
            object: nil
        )
        for controller in GCController.controllers() {
            connect(controller)
        }
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        GCController.stopWirelessControllerDiscovery()
    }

    func poll() {
        for index in controllers.indices {
            guard let controller = controllers[index],
                  let native = controller.extendedGamepad,
                  let gamepad = gamepads.gamepad(
                    at: index,
                    name: controller.vendorName ?? "Gamepad"
                  )
            else { continue }

            update(gamepad, from: native)
        }
    }

    @objc private func controllerDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        connect(controller)
    }

    @objc private func controllerDidDisconnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController,
              let index = controllers.firstIndex(where: { $0 === controller })
        else { return }
        controllers[index] = nil
        gamepads.disconnect(at: index)
    }

    private func connect(_ controller: GCController) {
        guard controller.extendedGamepad != nil,
              !controllers.contains(where: { $0 === controller })
        else { return }
        if let index = controllers.firstIndex(where: { $0 == nil }) {
            controllers[index] = controller
        } else {
            controllers.append(controller)
        }
    }

    private func update(_ gamepad: Gamepad, from native: GCExtendedGamepad) {
        update(gamepad, .south, native.buttonA)
        update(gamepad, .east, native.buttonB)
        update(gamepad, .west, native.buttonX)
        update(gamepad, .north, native.buttonY)
        update(gamepad, .leftShoulder, native.leftShoulder)
        update(gamepad, .rightShoulder, native.rightShoulder)
        update(gamepad, .leftTrigger, native.leftTrigger)
        update(gamepad, .rightTrigger, native.rightTrigger)
        if let button = native.leftThumbstickButton {
            update(gamepad, .leftStick, button)
        }
        if let button = native.rightThumbstickButton {
            update(gamepad, .rightStick, button)
        }
        update(gamepad, .up, native.dpad.up)
        update(gamepad, .down, native.dpad.down)
        update(gamepad, .left, native.dpad.left)
        update(gamepad, .right, native.dpad.right)
        update(gamepad, .menu, native.buttonMenu)
        if let button = native.buttonOptions {
            update(gamepad, .options, button)
        }

        gamepad.updateSticks(
            left: .init(
                Double(native.leftThumbstick.xAxis.value),
                Double(native.leftThumbstick.yAxis.value)
            ),
            right: .init(
                Double(native.rightThumbstick.xAxis.value),
                Double(native.rightThumbstick.yAxis.value)
            )
        )
    }

    private func update(
        _ gamepad: Gamepad,
        _ button: Gamepad.Button,
        _ native: GCControllerButtonInput
    ) {
        gamepad.update(
            button,
            value: Double(native.value),
            pressed: native.isPressed
        )
    }
}
