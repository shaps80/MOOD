import PixlPlatform

extension Key {
    init?(macKeyCode code: UInt16) {
        guard let key = Self.macKeys[code] else { return nil }
        self = key
    }

    private static let macKeys: [UInt16: Key] = [
        0: .a, 1: .s, 2: .d, 3: .f, 4: .h, 5: .g, 6: .z, 7: .x,
        8: .c, 9: .v, 11: .b, 12: .q, 13: .w, 14: .e, 15: .r,
        16: .y, 17: .t, 18: .one, 19: .two, 20: .three, 21: .four,
        22: .six, 23: .five, 24: .equal, 25: .nine, 26: .seven,
        27: .minus, 28: .eight, 29: .zero, 30: .bracketRight, 31: .o,
        32: .u, 33: .bracketLeft, 34: .i, 35: .p, 36: .enter, 37: .l,
        38: .j, 39: .quote, 40: .k, 41: .semicolon, 42: .backslash,
        43: .comma, 44: .slash, 45: .n, 46: .m, 47: .period, 48: .tab,
        49: .space, 50: .backquote, 51: .backspace, 53: .escape,
        54: .rightCommand, 55: .leftCommand, 56: .leftShift, 57: .capsLock,
        58: .leftOption, 59: .leftControl, 60: .rightShift, 61: .rightOption,
        62: .rightControl, 64: .f17, 65: .numpadDecimal,
        67: .numpadMultiply, 69: .numpadAdd, 71: .numLock,
        75: .numpadDivide, 76: .numpadEnter, 78: .numpadSubtract,
        79: .f18, 80: .f19, 81: .numpadEqual, 82: .numpadZero,
        83: .numpadOne, 84: .numpadTwo, 85: .numpadThree,
        86: .numpadFour, 87: .numpadFive, 88: .numpadSix,
        89: .numpadSeven, 90: .f20, 91: .numpadEight, 92: .numpadNine,
        96: .f5, 97: .f6, 98: .f7, 99: .f3, 100: .f8, 101: .f9,
        103: .f11, 105: .f13, 106: .f16, 107: .f14, 109: .f10,
        111: .f12, 113: .f15, 114: .help, 115: .home, 116: .pageUp,
        117: .delete, 118: .f4, 119: .end, 120: .f2, 121: .pageDown,
        122: .f1, 123: .arrowLeft, 124: .arrowRight,
        125: .arrowDown, 126: .arrowUp
    ]
}
