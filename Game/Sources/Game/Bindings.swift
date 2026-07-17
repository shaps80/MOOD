import Pixl
import Pixl2D

@InputProfile
struct PlayerBindings {
    @Binding(
        .key(.a),
        .key(.arrowLeft),
        .button(.left),
        .axis(.leftStickX, direction: .negative, deadZone: 0.12)
    ) let left: Input

    @Binding(
        .key(.d),
        .key(.arrowRight),
        .button(.right),
        .axis(.leftStickX, direction: .positive, deadZone: 0.12)
    ) let right: Input

    @Binding(
        .key(.w),
        .key(.arrowUp),
        .button(.up),
        .axis(.leftStickY, direction: .positive, deadZone: 0.12)
    ) let up: Input

    @Binding(
        .key(.s),
        .key(.arrowDown),
        .button(.down),
        .axis(.leftStickY, direction: .negative, deadZone: 0.12)
    ) let down: Input
}

extension PlayerBindings {
    var direction: Vec2 {
        .init(
            x: right.value - left.value,
            y: up.value - down.value
        )
    }
}
