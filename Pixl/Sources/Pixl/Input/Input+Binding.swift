import PixlPlatform
import PixlInput
import Swift

public extension Input {
    /// A physical source contributing to one semantic input.
    enum Binding: Hashable, Sendable {
        /// A physical keyboard key with an exact modifier requirement.
        case key(Key, modifiers: Key.Modifiers = [])
        /// A gamepad button or trigger.
        case button(Gamepad.Button)
        /// One directional half of a gamepad stick axis.
        case axis(Axis, direction: Direction, deadZone: Float = 0.12)
    }

    /// A physical gamepad stick component.
    enum Axis: UInt8, Hashable, Sendable {
        /// Horizontal component of the left stick.
        case leftStickX
        /// Vertical component of the left stick.
        case leftStickY
        /// Horizontal component of the right stick.
        case rightStickX
        /// Vertical component of the right stick.
        case rightStickY
    }

    /// The half-axis that activates a directional binding.
    enum Direction: Hashable, Sendable {
        /// Values below zero activate the input.
        case negative
        /// Values above zero activate the input.
        case positive
    }
}
