@preconcurrency import AppKit
import GameCore
import Swift

@MainActor
final class KeyboardInput {
    private var pressedKeys = Set<UInt16>()

    var state: Input {
        Input(
            horizontal: horizontalAxis,
            vertical: verticalAxis,
            jump: isPressed(KeyCode.space),
            reset: isPressed(KeyCode.escape)
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
             KeyCode.escape:
            return true
        default:
            return false
        }
    }
}

private enum KeyCode {
    static let a: UInt16 = 0
    static let s: UInt16 = 1
    static let d: UInt16 = 2
    static let w: UInt16 = 13
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}
