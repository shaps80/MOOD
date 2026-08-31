import Swift

public struct Elements<Element: BitwiseCopyable>: RandomAccessCollection {
    public typealias Index = Int
    public let baseAddress: UnsafePointer<Element>?
    public let count: Int

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(index: Int) -> Element {
        assert(index >= 0 && index < count, "Element index out of bounds")
        return baseAddress!.advanced(by: index).pointee
    }
}

public struct MutableElements<Element: BitwiseCopyable>: RandomAccessCollection, MutableCollection {
    public typealias Index = Int
    public let baseAddress: UnsafeMutablePointer<Element>?
    public let count: Int

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(index: Int) -> Element {
        get {
            assert(index >= 0 && index < count, "Element index out of bounds")
            return baseAddress!.advanced(by: index).pointee
        }
        nonmutating set {
            assert(index >= 0 && index < count, "Element index out of bounds")
            baseAddress!.advanced(by: index).pointee = newValue
        }
    }
}
