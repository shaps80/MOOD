import Swift

public struct AnyShape: Shape, Sendable {
    private let box: any AnyShapeBox

    public init<S: Shape & Equatable>(_ shape: S) {
        self.box = EquatableShapeBox(shape)
    }

    public init<S: Shape>(_ shape: S) {
        self.box = ShapeBox(shape)
    }

    public func path(in rect: Rect) -> Path {
        box.path(in: rect)
    }
}

extension AnyShape: Equatable {
    public static func == (lhs: AnyShape, rhs: AnyShape) -> Bool {
        lhs.box.isEqual(to: rhs.box)
    }
}

private protocol AnyShapeBox: Sendable {
    func path(in rect: Rect) -> Path
    func isEqual(to other: any AnyShapeBox) -> Bool
}

private struct EquatableShapeBox<S: Shape & Equatable>: AnyShapeBox {
    let shape: S

    init(_ shape: S) {
        self.shape = shape
    }

    func path(in rect: Rect) -> Path {
        shape.path(in: rect)
    }

    func isEqual(to other: any AnyShapeBox) -> Bool {
        guard let other = other as? Self else { return false }
        return shape == other.shape
    }
}

private struct ShapeBox<S: Shape>: AnyShapeBox {
    let shape: S

    init(_ shape: S) {
        self.shape = shape
    }

    func path(in rect: Rect) -> Path {
        shape.path(in: rect)
    }

    func isEqual(to other: any AnyShapeBox) -> Bool {
        false
    }
}
