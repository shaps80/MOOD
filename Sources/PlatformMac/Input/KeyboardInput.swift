@preconcurrency import AppKit
import Pixl
import Swift

@MainActor
final class KeyboardInput {
    private var pressedKeys = Set<UInt16>()

    var state: Input {
        Input(
            horizontal: horizontalAxis,
            vertical: verticalAxis,
            jump: isPressed(KeyCode.space),
            reset: isPressed(KeyCode.escape),
            debug: isPressed(KeyCode.grave),
            timeScale: timeScale
        )
    }

    @discardableResult
    func handleKeyEvent(_ event: NSEvent, isPressed: Bool) -> Bool {
        guard isControlKey(event.keyCode) else {
            return false
        }

        if isPressed {
            pressedKeys.insert(event.keyCode)
        } else {
            pressedKeys.remove(event.keyCode)
        }

        return true
    }

    func reset() {
        pressedKeys.removeAll(keepingCapacity: true)
    }

    private var horizontalAxis: Double {
        let left = isPressed(KeyCode.leftArrow) || isPressed(KeyCode.a)
        let right = isPressed(KeyCode.rightArrow) || isPressed(KeyCode.d)

        switch (left, right) {
        case (true, false):
            return -1
        case (false, true):
            return 1
        default:
            return 0
        }
    }

    private var verticalAxis: Double {
        let up = isPressed(KeyCode.upArrow) || isPressed(KeyCode.w)
        let down = isPressed(KeyCode.downArrow) || isPressed(KeyCode.s)

        switch (up, down) {
        case (true, false):
            return -1
        case (false, true):
            return 1
        default:
            return 0
        }
    }

    private func isPressed(_ keyCode: UInt16) -> Bool {
        pressedKeys.contains(keyCode)
    }

    private func isControlKey(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case KeyCode.upArrow,
             KeyCode.downArrow,
             KeyCode.leftArrow,
             KeyCode.rightArrow,
             KeyCode.w,
             KeyCode.a,
             KeyCode.s,
             KeyCode.d,
             KeyCode.space,
             KeyCode.escape,
             KeyCode.grave,
             KeyCode.one,
             KeyCode.two,
             KeyCode.three,
             KeyCode.four,
             KeyCode.five,
             KeyCode.six,
             KeyCode.seven,
             KeyCode.eight,
             KeyCode.nine:
            return true
        default:
            return false
        }
    }

    private var timeScale: Double? {
        for (keyCode, value) in KeyCode.timeScales where isPressed(keyCode) {
            return value
        }

        return nil
    }
}

private enum KeyCode {
    static let a: UInt16 = 0
    static let s: UInt16 = 1
    static let d: UInt16 = 2
    static let w: UInt16 = 13
    static let grave: UInt16 = 50
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let one: UInt16 = 18
    static let two: UInt16 = 19
    static let three: UInt16 = 20
    static let four: UInt16 = 21
    static let five: UInt16 = 23
    static let six: UInt16 = 22
    static let seven: UInt16 = 26
    static let eight: UInt16 = 28
    static let nine: UInt16 = 25
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126

    static let timeScales: [(UInt16, Double)] = [
        (one, 1),
        (two, 2),
        (three, 3),
        (four, 4),
        (five, 5),
        (six, 6),
        (seven, 7),
        (eight, 8),
        (nine, 9)
    ]
}
