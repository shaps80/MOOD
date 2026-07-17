import PixlPlatform
import Swift

public extension Input {
    enum Binding: Hashable, Sendable {
        case key(Key, modifiers: Key.Modifiers = [])
        case button(Gamepad.Button)
        case axis(Axis, direction: Direction, deadZone: Double = 0.12)
    }

    enum Axis: UInt8, Hashable, Sendable {
        case leftStickX
        case leftStickY
        case rightStickX
        case rightStickY
    }

    enum Direction: Hashable, Sendable {
        case negative
        case positive
    }
}
