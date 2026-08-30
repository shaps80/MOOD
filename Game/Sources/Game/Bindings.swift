import Pixl
import Pixl2D

@InputProfile
struct PlayerBindings {
    @InputMap(
        .key(.a),
        .key(.arrowLeft),
        .button(.left),
        .axis(.leftStickX, direction: .negative, deadZone: 0.12)
    ) var left

    @InputMap(
        .key(.d),
        .key(.arrowRight),
        .button(.right),
        .axis(.leftStickX, direction: .positive, deadZone: 0.12)
    ) var right

    @InputMap(
        .key(.w),
        .key(.arrowUp),
        .button(.up),
        .axis(.leftStickY, direction: .positive, deadZone: 0.12)
    ) var up

    @InputMap(
        .key(.s),
        .key(.arrowDown),
        .button(.west)
    ) var down

    @InputMap(
        .key(.space),
        .button(.south)
    ) var space

    @InputMap(
        .key(.leftShift),
        .key(.rightShift),
        .button(.leftStick)
    ) var run

    @InputMap(
        .key(.o),
        .button(.east)
    ) var dash
}

@InputProfile
struct CameraBindings {
    @InputMap(.key(.arrowLeft)) var left
    @InputMap(.key(.arrowRight)) var right
    @InputMap(.key(.arrowUp)) var up
    @InputMap(.key(.arrowDown)) var down
}

extension CameraBindings {
    var direction: Vec2 {
        .init(
            x: right.value - left.value,
            y: up.value - down.value
        )
    }
}

@InputProfile
struct GameBindings {
    @InputMap(
        .key(.escape),
        .button(.menu)
    ) var menu

    @InputMap(.key(.backquote)) var collisionDebug
}

@InputProfile
struct ShapeBindings {
    @InputMap(
        .key(.arrowUp)
    ) var up

    @InputMap(
        .key(.arrowDown)
    ) var down

    @InputMap(
        .key(.one)
    ) var inside

    @InputMap(
        .key(.two)
    ) var center

    @InputMap(
        .key(.three)
    ) var outside
}
