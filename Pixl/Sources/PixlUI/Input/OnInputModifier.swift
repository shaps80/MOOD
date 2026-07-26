import PixlInput
import Swift

struct _OnInputModifier: ViewModifier {
    typealias Body = Never

    let inputs: ContiguousArray<Input>
    let phases: UInt8
    let action: (Input, Input.Phase) -> Void

    static func _makeView(
        modifier: _GraphValue<Self>,
        inputs: _ViewInputs,
        body: @escaping (_Graph, _ViewInputs) -> _ViewOutputs
    ) -> _ViewOutputs {
        for input in modifier.value.inputs {
            inputs.graph.inputHandlers.append(
                .init(
                    input: input,
                    phases: modifier.value.phases,
                    action: modifier.value.action
                )
            )
        }
        return body(inputs.graph, inputs)
    }
}

public extension View {
    func onInput(
        _ input: Input,
        phases: [Input.Phase] = [.down],
        perform action: @escaping (Input, Input.Phase) -> Void
    ) -> some View {
        onInput([input], phases: phases, perform: action)
    }

    func onInput(
        _ inputs: [Input],
        phases: [Input.Phase] = [.down],
        perform action: @escaping (Input, Input.Phase) -> Void
    ) -> some View {
        precondition(!inputs.isEmpty, "onInput requires at least one input")
        precondition(!phases.isEmpty, "onInput requires at least one phase")
        var phaseMask: UInt8 = 0
        for phase in phases {
            phaseMask |= phase == .down ? 1 : 2
        }
        return modifier(
            _OnInputModifier(
                inputs: ContiguousArray(inputs),
                phases: phaseMask,
                action: action
            )
        )
    }
}
