import Swift

package struct ViewLayout: Sendable, CustomStringConvertible {
    package let size: Size
    package let displayScale: Float
    package let frames: ContiguousArray<Rect>
    package subscript(_ node: ViewGraph.NodeID) -> Rect { frames[Int(node.rawValue)] }
    package var description: String { frames.enumerated().map { "\($0.offset): \($0.element.debugDescription)" }.joined(separator: "\n") }
}

extension ViewGraph {
    package func layout(in size: Size, displayScale: Float = 1) -> ViewLayout {
        precondition(displayScale.isFinite && displayScale > 0, "displayScale must be finite and greater than zero")
        let pass = _LayoutPass(graph: self, displayScale: displayScale)
        var root = NodeID(rawValue: 0)
        while root.isValid {
            pass.place(
                root,
                Point(x: size.width / 2, y: size.height / 2),
                .center,
                ProposedViewSize(size),
                nil
            )
            root = nodes[Int(root.rawValue)].nextSibling
        }
        return .init(size: size, displayScale: displayScale, frames: pass.frames)
    }
}

struct _LayoutContext: Sendable {
    let displayScale: Float
    var pixelLength: Float { 1 / displayScale }

    func snap(_ value: Float) -> Float {
        (value * displayScale).rounded() / displayScale
    }

    func snap(_ rect: Rect) -> Rect {
        let minX = snap(rect.minX)
        let minY = snap(rect.minY)
        let maxX = snap(rect.maxX)
        let maxY = snap(rect.maxY)
        return .init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

final class _LayoutPass: _LayoutSubviewStorage, @unchecked Sendable {
    let graph: ViewGraph
    let context: _LayoutContext
    var frames: ContiguousArray<Rect>
    private var caches: [Int: Any] = [:]
    init(graph: ViewGraph, displayScale: Float) {
        self.graph = graph
        context = .init(displayScale: displayScale)
        frames = .init(repeating: .zero, count: graph.nodes.count)
    }

    override func sizeThatFits(_ id: ViewGraph.NodeID, _ proposal: ProposedViewSize, _ orientation: Axis?) -> Size { measure(id, proposal, orientation) }
    override func place(_ id: ViewGraph.NodeID, _ position: Point, _ anchor: UnitPoint, _ proposal: ProposedViewSize, _ orientation: Axis?) { placeNode(id, position, anchor, proposal, orientation) }

    private func subviews(_ id: ViewGraph.NodeID, orientation: Axis?) -> LayoutSubviews {
        .init(storage: self, ids: graph.children, bounds: graph.childRanges[Int(id.rawValue)], orientation: orientation)
    }

    private func finite(_ value: Float?) -> Float? { guard let value, value.isFinite else { return value }; return max(0, value) }
    private func flexible(_ value: Float?, ideal: Float = 0) -> Float { value ?? ideal }

    private func measure(_ id: ViewGraph.NodeID, _ proposal: ProposedViewSize, _ orientation: Axis?) -> Size {
        let node = graph.nodes[Int(id.rawValue)]
        switch node.kind {
        case .empty: return .zero
        case .primitive:
            switch graph.primitives[Int(node.payload)] {
            case .text(let text):
                return measureText(text.content, proposal: proposal)
            case .fill:
                return .init(width: flexible(proposal.width), height: flexible(proposal.height))
            case .spacer(let minimum):
                let minimum = minimum ?? 0
                if orientation == .horizontal { return .init(width: proposal.width ?? minimum, height: proposal.height ?? 0) }
                if orientation == .vertical { return .init(width: proposal.width ?? 0, height: proposal.height ?? minimum) }
                return .init(width: proposal.width ?? minimum, height: proposal.height ?? minimum)
            case .divider:
                if orientation == .horizontal { return .init(width: context.pixelLength, height: proposal.height ?? 0) }
                return .init(width: proposal.width ?? 0, height: context.pixelLength)
            }
        case .layout:
            let index = Int(node.payload), box = graph.layouts[index].box
            let views = subviews(id, orientation: box.layoutProperties.stackOrientation)
            var cache: Any? = caches[index] ?? box.makeCache(subviews: views)
            let result = box.sizeThatFits(proposal: proposal, subviews: views, cache: &cache)
            if let cache { caches[index] = cache }; return result
        case .shape:
            return graph.shapes[Int(node.payload)].shape.sizeThatFits(proposal)
        case .composition:
            let range = graph.childRanges[Int(id.rawValue)]
            guard !range.isEmpty else { return .zero }
            let composition = graph.compositions[Int(node.payload)]
            let primaryIndex = composition.order == .background ? range.index(before: range.endIndex) : range.startIndex
            return measure(graph.children[primaryIndex], proposal, orientation)
        case .group:
            var result = Size.zero
            for child in subviews(id, orientation: orientation) { let size = child.sizeThatFits(proposal); result.width = max(result.width, size.width); result.height = max(result.height, size.height) }
            return result
        }
    }

    private func measureText(_ text: String, proposal: ProposedViewSize) -> Size {
        guard !text.isEmpty else { return .zero }

        let glyphWidth: Float = 20
        let lineHeight: Float = 30
        let lineSpacing: Float = 0

        let columns: Int
        if let width = proposal.width, width.isFinite {
            columns = max(1, Int(width / glyphWidth))
        } else {
            columns = .max
        }

        var lineCount = 0
        var widestLine = 0
        for logicalLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let characterCount = logicalLine.count
            let wrappedLines = max(1, columns == .max ? 1 : (characterCount + columns - 1) / columns)
            lineCount += wrappedLines
            widestLine = max(widestLine, columns == .max ? characterCount : min(characterCount, columns))
        }

        if let height = proposal.height, height.isFinite {
            let visibleLines = max(1, Int((height + lineSpacing) / (lineHeight + lineSpacing)))
            lineCount = min(lineCount, visibleLines)
        }

        return .init(
            width: Float(widestLine) * glyphWidth,
            height: Float(lineCount) * lineHeight + Float(max(0, lineCount - 1)) * lineSpacing
        )
    }

    private func placeNode(_ id: ViewGraph.NodeID, _ position: Point, _ anchor: UnitPoint, _ proposal: ProposedViewSize, _ orientation: Axis?) {
        let size = measure(id, proposal, orientation)
        let bounds = Rect(origin: .init(x: position.x - anchor.x * size.width, y: position.y - anchor.y * size.height), size: size)
        let node = graph.nodes[Int(id.rawValue)]
        switch node.kind {
        case .primitive, .shape:
            frames[Int(id.rawValue)] = context.snap(bounds)
        default:
            frames[Int(id.rawValue)] = bounds
        }
        switch node.kind {
        case .layout:
            let index = Int(node.payload), box = graph.layouts[index].box, views = subviews(id, orientation: box.layoutProperties.stackOrientation)
            var cache: Any? = caches[index] ?? box.makeCache(subviews: views)
            box.placeSubviews(in: bounds, proposal: proposal, subviews: views, cache: &cache); if let cache { caches[index] = cache }
        case .composition:
            let range = graph.childRanges[Int(id.rawValue)]
            guard !range.isEmpty else { return }
            let composition = graph.compositions[Int(node.payload)]
            let primary = composition.order == .background ? graph.children[range.index(before: range.endIndex)] : graph.children[range.startIndex]
            placeNode(primary, bounds.origin, .topLeading, .init(size), orientation)
            let alignment = composition.alignment
            let container = ViewDimensions(size: size)
            for index in range where graph.children[index] != primary {
                let child = graph.children[index]
                let childSize = measure(child, .init(size), orientation)
                let dimensions = ViewDimensions(size: childSize)
                let point = Point(
                    x: bounds.minX + container[alignment.horizontal] - dimensions[alignment.horizontal],
                    y: bounds.minY + container[alignment.vertical] - dimensions[alignment.vertical]
                )
                placeNode(child, point, .topLeading, .init(childSize), orientation)
            }
        case .group:
            for child in graph.children[graph.childRanges[Int(id.rawValue)]] { placeNode(child, .init(x: bounds.midX, y: bounds.midY), .center, proposal, orientation) }
        default: break
        }
    }
}
