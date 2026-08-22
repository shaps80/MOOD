import SwiftUI

@frozen public struct _GraphValue<Value> {
    @usableFromInline
    internal var value: Value

    @inlinable internal init(_ value: Value) {
        self.value = value
    }

    @inlinable internal subscript<T>(keyPath: KeyPath<Value, T>) -> _GraphValue<T> {
        .init(value[keyPath: keyPath])
    }
}

extension _GraphValue: Equatable where Value: Equatable {
    @inlinable public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value == rhs.value
    }
}

public struct _PanelInputs: Sendable {
    var defaultAlignment: UnitPoint = .trailing
    var defaultVisiblity: Visibility = .visible
}

public struct _PanelOutputs: Sendable {
    var panels: [_Panel] = []
}

struct _Panel: Identifiable {
    var id: String
    var widths: (min: CGFloat, ideal: CGFloat?, max: CGFloat?)
    var defaultAlignment: UnitPoint
    var defaultVisiblity: Visibility
    var content: () -> any View
}
