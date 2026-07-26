import PixlPlatform
import PixlInput
import Swift

public extension Input {
    /// Binds semantic input profiles to the runtime's physical input devices.
    final class Map {
        private let keyboard: Keyboard
        private let gamepads: Gamepads
        private var profiles: ContiguousArray<Profile> = []

        init(keyboard: Keyboard, gamepads: Gamepads) {
            self.keyboard = keyboard
            self.gamepads = gamepads
        }

        /// Binds a profile to the keyboard and first connected gamepad.
        /// - Parameter profile: Profile to update each presentation frame. Rebinding the same object has no effect.
        public func bind(_ profile: Profile) {
            guard !profiles.contains(where: { $0 === profile }) else { return }
            profiles.append(profile)
        }

        func bind(_ input: Input) {
            guard let profile = input.owner as? Profile else {
                preconditionFailure("Input was created by an incompatible profile")
            }
            bind(profile)
        }

        func update() {
            let modifiers = currentModifiers
            let gamepad = gamepads.first
            for profile in profiles {
                profile.update(
                    keyboard: keyboard,
                    modifiers: modifiers,
                    gamepad: gamepad
                )
            }
        }

        private var currentModifiers: Key.Modifiers {
            var modifiers: Key.Modifiers = []
            if keyboard.contains(.leftCommand)
                || keyboard.contains(.rightCommand) {
                modifiers.insert(.command)
            }
            if keyboard.contains(.leftControl)
                || keyboard.contains(.rightControl) {
                modifiers.insert(.control)
            }
            if keyboard.contains(.leftOption)
                || keyboard.contains(.rightOption) {
                modifiers.insert(.option)
            }
            if keyboard.contains(.leftShift)
                || keyboard.contains(.rightShift) {
                modifiers.insert(.shift)
            }
            return modifiers
        }
    }
}
