import Pixl
import Pixl2D

struct PlayerProfile {
    let storage: Input.Profile

    let left: Input
    let right: Input
    let up: Input
    let down: Input

    var direction: Vec2 {
        .init(
            x: right.value - left.value,
            y: up.value - down.value
        )
    }

    init() {
        let storage = Input.Profile()

        self.storage = storage
        left = storage.input(
            bindings: [
                .key(.a),
                .key(.arrowLeft),
                .button(.left),
                .axis(.leftStickX, direction: .negative, deadZone: 0.12)
            ]
        )

        right = storage.input(
            bindings: [
                .key(.d),
                .key(.arrowRight),
                .button(.right),
                .axis(.leftStickX, direction: .positive, deadZone: 0.12)
            ]
        )

        up = storage.input(
            bindings: [
                .key(.w),
                .key(.arrowUp),
                .button(.up),
                .axis(.leftStickY, direction: .positive, deadZone: 0.12)
            ]
        )

        down = storage.input(
            bindings: [
                .key(.s),
                .key(.arrowDown),
                .button(.down),
                .axis(.leftStickY, direction: .negative, deadZone: 0.12)
            ]
        )
    }
}
