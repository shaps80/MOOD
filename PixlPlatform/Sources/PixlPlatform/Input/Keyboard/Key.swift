import Swift

/// The physical position of a keyboard key, independent of keyboard layout.
public enum Key: UInt8, CaseIterable, Hashable, Sendable {
    /// Physical alphabetic key positions A through M.
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    /// Physical alphabetic key positions N through Z.
    case n, o, p, q, r, s, t, u, v, w, x, y, z
    /// Number-row key positions zero through nine.
    case zero, one, two, three, four, five, six, seven, eight, nine
    /// Number-row punctuation and bracket key positions.
    case backquote, minus, equal, bracketLeft, bracketRight, backslash
    /// Remaining punctuation key positions.
    case semicolon, quote, comma, period, slash
    /// Whitespace, confirmation, deletion, and escape key positions.
    case space, tab, enter, backspace, escape
    /// Directional arrow key positions.
    case arrowLeft, arrowRight, arrowUp, arrowDown
    /// Navigation and editing key positions.
    case insert, delete, home, end, pageUp, pageDown
    /// Lock, print-screen, and pause key positions.
    case capsLock, numLock, scrollLock, printScreen, pause
    /// Left and right Shift key positions.
    case leftShift, rightShift
    /// Left and right Control key positions.
    case leftControl, rightControl
    /// Left and right Option/Alt key positions.
    case leftOption, rightOption
    /// Left and right Command/Windows key positions.
    case leftCommand, rightCommand
    /// Context-menu key position.
    case contextMenu
    /// Function key positions F1 through F10.
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10
    /// Function key positions F11 through F20.
    case f11, f12, f13, f14, f15, f16, f17, f18, f19, f20
    /// Numeric-keypad digit positions zero through four.
    case numpadZero, numpadOne, numpadTwo, numpadThree, numpadFour
    /// Numeric-keypad digit positions five through nine.
    case numpadFive, numpadSix, numpadSeven, numpadEight, numpadNine
    /// Numeric-keypad decimal and arithmetic positions.
    case numpadDecimal, numpadAdd, numpadSubtract, numpadMultiply
    /// Remaining numeric-keypad operation positions.
    case numpadDivide, numpadEnter, numpadEqual, numpadComma
    /// Help key position.
    case help
}

public extension Key {
    /// One physical key transition published for a presentation frame.
    struct Event: Hashable, Sendable {
        /// Physical key that transitioned.
        public let key: Key
        /// Whether the key moved down or up.
        public let phase: Phase
        /// Complete modifier state at the time of the transition.
        public let modifiers: Modifiers
        /// Whether this is a native auto-repeat down event.
        public let isRepeat: Bool

        /// Creates a physical key transition.
        /// - Parameters:
        ///   - key: Physical key that transitioned.
        ///   - phase: Whether the key moved down or up.
        ///   - modifiers: Complete modifier state at the transition.
        ///   - isRepeat: Whether this is an auto-repeat down event.
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

    /// Direction of a physical key transition.
    enum Phase: Hashable, Sendable {
        /// The key became held.
        case down
        /// The key stopped being held.
        case up
    }

    /// Modifier keys held during a key transition.
    struct Modifiers: OptionSet, Hashable, Sendable {
        /// Raw modifier bitmask.
        public let rawValue: UInt8

        /// Creates modifiers from a raw bitmask.
        /// - Parameter rawValue: Bitmask composed from ``Modifiers`` constants.
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// Either Command key.
        public static let command = Self(rawValue: 1 << 0)
        /// Either Control key.
        public static let control = Self(rawValue: 1 << 1)
        /// Either Option/Alt key.
        public static let option = Self(rawValue: 1 << 2)
        /// Either Shift key.
        public static let shift = Self(rawValue: 1 << 3)
    }
}
