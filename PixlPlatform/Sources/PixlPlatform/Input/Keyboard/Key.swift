import Swift

/// The physical position of a keyboard key, independent of keyboard layout.
public enum Key: UInt8, CaseIterable, Hashable, Sendable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z
    case zero, one, two, three, four, five, six, seven, eight, nine
    case backquote, minus, equal, bracketLeft, bracketRight, backslash
    case semicolon, quote, comma, period, slash
    case space, tab, enter, backspace, escape
    case arrowLeft, arrowRight, arrowUp, arrowDown
    case insert, delete, home, end, pageUp, pageDown
    case capsLock, numLock, scrollLock, printScreen, pause
    case leftShift, rightShift
    case leftControl, rightControl
    case leftOption, rightOption
    case leftCommand, rightCommand
    case contextMenu
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10
    case f11, f12, f13, f14, f15, f16, f17, f18, f19, f20
    case numpadZero, numpadOne, numpadTwo, numpadThree, numpadFour
    case numpadFive, numpadSix, numpadSeven, numpadEight, numpadNine
    case numpadDecimal, numpadAdd, numpadSubtract, numpadMultiply
    case numpadDivide, numpadEnter, numpadEqual, numpadComma
    case help
}

public extension Key {
    struct Event: Hashable, Sendable {
        public let key: Key
        public let phase: Phase
        public let modifiers: Modifiers
        public let isRepeat: Bool

        public init(
            key: Key,
            phase: Phase,
            modifiers: Modifiers = [],
            isRepeat: Bool = false
        ) {
            self.key = key
            self.phase = phase
            self.modifiers = modifiers
            self.isRepeat = isRepeat
        }
    }

    enum Phase: Hashable, Sendable {
        case down
        case up
    }

    struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let command = Self(rawValue: 1 << 0)
        public static let control = Self(rawValue: 1 << 1)
        public static let option = Self(rawValue: 1 << 2)
        public static let shift = Self(rawValue: 1 << 3)
    }
}
