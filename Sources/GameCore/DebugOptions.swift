import Swift

struct DebugOptions: OptionSet, Sendable {
    let rawValue: UInt8

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    static let colliders = DebugOptions(rawValue: 1 << 0)
    static let visibility = DebugOptions(rawValue: 1 << 1)
}


extension DebugOptions {
    mutating func toggle(_ option: DebugOptions) {
        if contains(option) {
            remove(option)
        } else {
            insert(option)
        }
    }
}
