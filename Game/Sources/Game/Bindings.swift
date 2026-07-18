import Pixl
import Pixl2D

@InputProfile
struct PlayerBindings {
    @Binding(
        .key(.a),
        .key(.arrowLeft),
        .button(.left),
        .axis(.leftStickX, direction: .negative, deadZone: 0.12)
    ) var left

    @Binding(
        .key(.d),
        .key(.arrowRight),
        .button(.right),
        .axis(.leftStickX, direction: .positive, deadZone: 0.12)
    ) var right

    @Binding(
        .key(.w),
        .key(.arrowUp),
        .button(.up),
        .axis(.leftStickY, direction: .positive, deadZone: 0.12)
    ) var up

    @Binding(
        .key(.s),
        .key(.arrowDown),
        .button(.down),
        .axis(.leftStickY, direction: .negative, deadZone: 0.12)
    ) var down
}

extension PlayerBindings {
    var velocity: Vec2 {
        .init(
            x: right.value - left.value,
            y: up.value - down.value
        )
    }
}

@InputProfile
struct GameBindings {
    @Binding(
        .key(.escape),
        .button(.menu)
    ) var menu
}
