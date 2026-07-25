import Swift

/// An alignment position along the vertical axis.
///
/// Use vertical alignment guides to position views
/// relative to one another vertically, like when you place views side-by-side
/// in an ``HStack`` or when you create a row of views in a ``Grid`` using
/// ``GridRow``. The following example demonstrates common built-in
/// vertical alignments:
///
/// ![Five rows of content. Each row contains text inside
/// a box with horizontal lines to the left and the right of the box. The
/// lines are aligned vertically with the text in a different way for each
/// row, corresponding to the content of the text in that row. The text strings
/// are, in order, top, center, bottom, first text baseline, and last text
/// baseline.](VerticalAlignment-1-iOS)
///
/// You can generate the example above by creating a series of rows
/// implemented as horizontal stacks, where you configure each stack with a
/// different alignment guide:
///
///     private struct VerticalAlignmentGallery: Element {
///         var body: some Element {
///             VStack(spacing: 30) {
///                 row(alignment: .top, text: "Top")
///                 row(alignment: .center, text: "Center")
///                 row(alignment: .bottom, text: "Bottom")
///                 row(alignment: .firstTextBaseline, text: "First Text Baseline")
///                 row(alignment: .lastTextBaseline, text: "Last Text Baseline")
///             }
///         }
///
///         private func row(alignment: VerticalAlignment, text: String) -> some Element {
///             HStack(alignment: alignment, spacing: 0) {
///                 Color.red.frame(height: 1)
///                 Text(text).font(.title).border(.gray)
///                 Color.red.frame(height: 1)
///             }
///         }
///     }
///
/// During layout, SwiftUI aligns the views inside each stack by bringing
/// together the specified guides of the affected views. SwiftUI calculates
/// the position of a guide for a particular view based on the characteristics
/// of the view. For example, the ``VerticalAlignment/center`` guide appears
/// at half the height of the view. You can override the guide calculation for a
/// particular view using the ``Element/alignmentGuide(_:computeValue:)-6y3u2``
/// view modifier.
///
/// ### Text baseline alignment
///
/// Use the ``VerticalAlignment/firstTextBaseline`` or
/// ``VerticalAlignment/lastTextBaseline`` guide to match the bottom of either
/// the top- or bottom-most line of text that a view contains, respectively.
/// Text baseline alignment excludes the parts of characters that descend
/// below the baseline, like the tail on lower case g and j:
///
///     row(alignment: .firstTextBaseline, text: "fghijkl")
///
/// If you use a text baseline alignment on a view that contains no text,
/// SwiftUI applies the equivalent of ``VerticalAlignment/bottom`` alignment
/// instead. For the row in the example above, SwiftUI matches the bottom of
/// the horizontal lines with the baseline of the text:
///
/// ![A string containing the lowercase letters f, g, h, i, j, and
/// k. The string is inside a box, and horizontal lines appear to the left and
/// to the right of the box. The lines align with the bottom of the text,
/// excluding the descenders of letters g and j, which extend below the
/// baseline.](VerticalAlignment-2-iOS)
///
/// Aligning a text view to its baseline rather than to the bottom of its frame
/// produces the best layout effect in many cases, like when creating forms.
/// For example, you can align the baseline of descriptive text in
/// one ``GridRow`` cell with the baseline of a text field, or the label
/// of a checkbox, in another cell in the same row.
///
/// ### Custom alignment guides
///
/// You can create a custom vertical alignment guide by first creating a type
/// that conforms to the ``AlignmentID`` protocol, and then using that type to
/// initalize a new static property on `VerticalAlignment`:
///
///     private struct FirstThirdAlignment: AlignmentID {
///         static func defaultValue(in context: ViewDimensions) -> Double {
///             context.height / 3
///         }
///     }
///
///     extension VerticalAlignment {
///         static let firstThird = VerticalAlignment(FirstThirdAlignment.self)
///     }
///
/// You implement the ``AlignmentID/defaultValue(in:)`` method to calculate
/// a default value for the custom alignment guide. The method receives a
/// ``ViewDimensions`` instance that you can use to calculate a
/// value based on characteristics of the view. The example above places
/// the guide at one-third of the height of the view as measured from the
/// view's origin.
///
/// You can then use the custom alignment guide like any built-in guide. For
/// example, you can use it as the `alignment` parameter to an ``HStack``,
/// or to alter the guide calculation for a specific view using the
/// ``Element/alignmentGuide(_:computeValue:)-6y3u2`` view modifier.
///
/// ### Composite alignment
///
/// Combine a `VerticalAlignment` with a ``HorizontalAlignment`` to create a
/// composite ``Alignment`` that indicates both vertical and horizontal
/// positioning in one value. For example, you could combine your custom
/// `firstThird` vertical alignment from the previous section with a built-in
/// ``HorizontalAlignment/center`` horizontal alignment to use in a ``ZStack``:
///
///     struct LayeredHorizontalStripes: Element {
///         var body: some Element {
///             ZStack(alignment: Alignment(horizontal: .center, vertical: .firstThird)) {
///                 horizontalStripes(color: .blue)
///                     .frame(width: 180, height: 90)
///                 horizontalStripes(color: .green)
///                     .frame(width: 70, height: 60)
///             }
///         }
///
///         private func horizontalStripes(color: Color) -> some Element {
///             VStack(spacing: 1) {
///                 ForEach(0..<3) { _ in color }
///             }
///         }
///     }
///
/// The example above uses widths and heights that generate two mismatched
/// sets of three vertical stripes. The ``ZStack`` centers the two sets
/// horizontally and aligns them vertically one-third from the top
/// of each set. This aligns the bottom edges of the top stripe from each set:
///
/// ![Two sets of three vertically stacked rectangles. The first
/// set is blue. The second set of rectangles are green, smaller, and layered
/// on top of the first set. The two sets are centered horizontally, but align
/// vertically at the bottom edge of each set's top-most
/// rectangle.](VerticalAlignment-3-iOS)
@frozen public struct VerticalAlignment: Equatable, Sendable {
    private let id: AlignmentID.Type

    /// Creates a custom vertical alignment of the specified type.
    ///
    /// Use this initializer to create a custom vertical alignment. Define
    /// an ``AlignmentID`` type, and then use that type to create a new
    /// static property on ``VerticalAlignment``:
    ///
    ///     private struct FirstThirdAlignment: AlignmentID {
    ///         static func defaultValue(in context: ViewDimensions) -> Double {
    ///             context.height / 3
    ///         }
    ///     }
    ///
    ///     extension VerticalAlignment {
    ///         static let firstThird = VerticalAlignment(FirstThirdAlignment.self)
    ///     }
    ///
    /// Every vertical alignment instance that you create needs a unique
    /// identifier. For more information, see ``AlignmentID``.
    ///
    /// - Parameter id: The type of an identifier that uniquely identifies a
    ///   vertical alignment.
    public init(_ id: AlignmentID.Type) {
        self.id = id
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension VerticalAlignment {
    /// A guide that marks the first baseline of the view.
    public static var firstBaseline: VerticalAlignment { .init(VFirstBaseline.self) }

    /// A guide that marks the top edge of the view.
    public static var lastBaseline: VerticalAlignment { .init(VLastBaseline.self) }

    /// A guide that marks the top edge of the view.
    public static var top: VerticalAlignment { .init(VTop.self) }

    /// A guide that marks the vertical center of the view.
    public static var center: VerticalAlignment { .init(VCenter.self) }

    /// A guide that marks the bottom edge of the view.
    public static var bottom: VerticalAlignment { .init(VBottom.self) }
}

private enum VFirstBaseline: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> String { "first baseline" }
}

private enum VLastBaseline: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> String { "last baseline" }
}

private enum VTop: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> String { "start" }
}

private enum VCenter: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> String { "center" }
}

private enum VBottom: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> String { "end" }
}

extension VerticalAlignment: CustomStringConvertible {
    public var description: String { id.defaultValue(in: .init()) }
}
