import Swift

/// A collection of proxy values that represent the subviews of a layout view.
///
/// You receive a `LayoutSubviews` input to your implementations of
/// ``Layout`` protocol methods, like
/// ``Layout/placeSubviews(in:proposal:subviews:cache:)`` and
/// ``Layout/sizeThatFits(proposal:subviews:cache:)``. The `subviews`
/// parameter (which the protocol aliases to the ``Layout/Subviews`` type)
/// is a collection that contains proxies for the layout's subviews (of type
/// ``LayoutSubview``). The proxies appear in the collection in the same
/// order that they appear in the ``ViewBuilder`` input to the layout
/// container. Use the proxies to perform layout operations.
///
/// Access the proxies in the collection as you would the contents of any
/// Swift random-access collection. For example, you can enumerate all of the
/// subviews and their indices to inspect or operate on them:
///
///     for (index, subview) in subviews.enumerated() {
///         // ...
///     }
///
public struct LayoutSubviews: Equatable, RandomAccessCollection, Sendable {
    /// A type that represents the indices that are valid for subscripting the
    /// collection, in ascending order.
    public typealias Indices = Range<LayoutSubviews.Index>

    /// A type that provides the collection's iteration interface and
    /// encapsulates its iteration state.
    ///
    /// By default, a collection conforms to the `Sequence` protocol by
    /// supplying `IndexingIterator` as its associated `Iterator`
    /// type.
    public typealias Iterator = IndexingIterator<LayoutSubviews>

    /// A type that contains a subsequence of proxy values.
    public typealias SubSequence = LayoutSubviews

    /// A type that contains a proxy value.
    public typealias Element = LayoutSubview

    /// A type that you can use to index proxy values.
    public typealias Index = Int

    private let storage: [Element]

    /// The layout direction inherited by the container view.
    ///
    /// SwiftUI supports both left-to-right and right-to-left directions.
    /// Read this property within a custom layout container
    /// to find out which environment the container is in.
    ///
    /// In most cases, you don't need to take any action based on this
    /// value. SwiftUI horizontally flips the x position of each view within its
    /// parent when the mode switches, so layout calculations automatically
    /// produce the desired effect for both directions.
    public var layoutDirection: LayoutDirection

    /// The index of the first subview.
    public var startIndex: Int { storage.startIndex }

    /// An index that's one higher than the last subview.
    public var endIndex: Int { storage.endIndex }

    /// Gets the subview proxy at a specified index.
    public subscript(index: Int) -> LayoutSubviews.Element { storage[index] }

    /// Gets the subview proxies in the specified range.
    public subscript(bounds: Range<Int>) -> LayoutSubviews {
        .init(storage: Array(storage[bounds]), layoutDirection: layoutDirection)
    }

    /// Gets the subview proxies with the specified indicies.
    public subscript<S>(indices: S) -> LayoutSubviews where S: Sequence, S.Element == Int {
        .init(storage: indices.map { storage[$0] }, layoutDirection: layoutDirection)
    }
}
