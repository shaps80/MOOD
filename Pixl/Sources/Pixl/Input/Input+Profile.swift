import PixlPlatform
import PixlInput
import Swift

public extension Input {
    /// A game-defined collection of semantic inputs and their bindings.
    final class Profile {
        private struct KeyBinding {
            let inputIndex: Int
            let key: Key
            let modifiers: Key.Modifiers
        }

        private struct ButtonBinding {
            let inputIndex: Int
            let button: Gamepad.Button
        }

        private struct AxisBinding {
            let inputIndex: Int
            let axisIndex: Int
            let scale: Float
            let deadZone: Float
        }

        private let storage = Storage()
        private var sourceBindings: ContiguousArray<
            ContiguousArray<Binding>
        > = []
        private var keyBindings: ContiguousArray<KeyBinding> = []
        private var buttonBindings: ContiguousArray<ButtonBinding> = []
        private var axisBindings: ContiguousArray<AxisBinding> = []

        /// Creates an empty semantic input profile.
        public init() {}

        /// Creates a semantic input driven by the supplied physical bindings.
        /// - Parameter bindings: Nonempty list of sources combined by their strongest value.
        /// - Returns: A stable semantic input backed by this profile.
        public func input(bindings: [Binding]) -> Input {
            precondition(!bindings.isEmpty, "An input requires a binding")
            validate(bindings)
            let inputIndex = storage.states.count

            sourceBindings.append(ContiguousArray(bindings))
            storage.states.append(State())
            compile(bindings, for: inputIndex)
            return Input(
                storage: storage,
                index: inputIndex,
                owner: self
            )
        }

        /// Replaces one semantic input's physical bindings.
        /// The rebuilt bindings take effect on the next presentation frame.
        /// - Parameters:
        ///   - bindings: Replacement physical sources. An empty list disables the input.
        ///   - input: Semantic input previously created by this profile.
        public func setBindings(
            _ bindings: [Binding],
            for input: Input
        ) {
            guard let inputIndex = input.index(in: storage) else {
                preconditionFailure("The input belongs to another profile")
            }
            validate(bindings)
            sourceBindings[inputIndex] = ContiguousArray(bindings)
            rebuildCompiledBindings()
        }

        func update(
            keyboard: Keyboard,
            modifiers: Key.Modifiers,
            gamepad: Gamepad?
        ) {
            resetStates()
            resolveKeys(keyboard: keyboard, modifiers: modifiers)

            guard let gamepad else { return }
            resolveButtons(gamepad: gamepad)
            resolveAxes(gamepad: gamepad)
        }

        private func resetStates() {
            for index in storage.states.indices {
                storage.states[index].previousValue = storage.states[index].value
                storage.states[index].value = 0
            }
        }

        private func validate(_ bindings: [Binding]) {
            for binding in bindings {
                guard case let .axis(_, _, deadZone) = binding else { continue }
                precondition(
                    deadZone.isFinite && deadZone >= 0 && deadZone < 1,
                    "An axis dead zone must be finite and in 0..<1"
                )
            }
        }

        private func rebuildCompiledBindings() {
            keyBindings.removeAll(keepingCapacity: true)
            buttonBindings.removeAll(keepingCapacity: true)
            axisBindings.removeAll(keepingCapacity: true)

            for inputIndex in sourceBindings.indices {
                compile(sourceBindings[inputIndex], for: inputIndex)
            }
        }

        private func compile<S: Sequence>(
            _ bindings: S,
            for inputIndex: Int
        ) where S.Element == Binding {
            for binding in bindings {
                switch binding {
                case let .key(key, modifiers):
                    keyBindings.append(.init(
                        inputIndex: inputIndex,
                        key: key,
                        modifiers: modifiers
                    ))

                case let .button(button):
                    buttonBindings.append(.init(
                        inputIndex: inputIndex,
                        button: button
                    ))

                case let .axis(axis, direction, deadZone):
                    axisBindings.append(.init(
                        inputIndex: inputIndex,
                        axisIndex: Int(axis.rawValue),
                        scale: direction == .negative ? -1 : 1,
                        deadZone: deadZone
                    ))
                }
            }
        }

        private func resolveKeys(
            keyboard: Keyboard,
            modifiers: Key.Modifiers
        ) {
            for binding in keyBindings {
                guard keyboard.contains(binding.key),
                      modifiers == binding.modifiers
                else {
                    continue
                }
                storage.states[binding.inputIndex].value = 1
            }
        }

        private func resolveButtons(gamepad: Gamepad) {
            for binding in buttonBindings {
                combine(
                    gamepad.value(for: binding.button),
                    into: binding.inputIndex
                )
            }
        }

        private func resolveAxes(gamepad: Gamepad) {
            let axes = SIMD4<Float>(
                gamepad.leftStick.x,
                gamepad.leftStick.y,
                gamepad.rightStick.x,
                gamepad.rightStick.y
            )

            for binding in axisBindings {
                let directionalValue = max(
                    axes[binding.axisIndex] * binding.scale,
                    0
                )
                guard directionalValue > binding.deadZone else { continue }

                combine(
                    min(
                        (directionalValue - binding.deadZone)
                            / (1 - binding.deadZone),
                        1
                    ),
                    into: binding.inputIndex
                )
            }
        }

        private func combine(_ value: Float, into inputIndex: Int) {
            storage.states[inputIndex].value = max(
                storage.states[inputIndex].value,
                value
            )
        }
    }
}
