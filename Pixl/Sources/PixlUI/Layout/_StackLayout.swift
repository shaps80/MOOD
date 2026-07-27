import Swift

enum _StackLayout {
    struct Allocation {
        var index: Int
        var size: Size
    }

    private struct Element {
        var index: Int
        var flexibility: _LayoutFlexibility
        var priority: Float
    }

    static func allocate(
        _ subviews: LayoutSubviews,
        along axis: Axis,
        proposal: Float?,
        cross: Float?,
        spacing: Float
    ) -> ContiguousArray<Allocation> {
        let spacing = Float(max(0, subviews.count - 1)) * spacing
        let available = proposal.map { max(0, $0 - spacing) }
        var elements = ContiguousArray<Element>()
        elements.reserveCapacity(subviews.count)

        for index in subviews.indices {
            let subview = subviews[index]
            elements.append(.init(
                index: index,
                flexibility: subview.flexibility(along: axis, cross: cross),
                priority: subview.priority
            ))
        }

        elements.sort {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.flexibility.range != $1.flexibility.range { return $0.flexibility.range < $1.flexibility.range }
            return $0.index < $1.index
        }

        var remaining = available
        var remainingCount = elements.count
        var allocations = ContiguousArray<Allocation>()
        allocations.reserveCapacity(elements.count)

        for element in elements {
            let mainProposal: Float?
            if let remaining {
                mainProposal = remaining.isInfinite ? .infinity : max(0, remaining / Float(remainingCount))
            } else {
                mainProposal = nil
            }

            let proposed: ProposedViewSize = switch axis {
            case .horizontal: .init(width: mainProposal, height: cross)
            case .vertical: .init(width: cross, height: mainProposal)
            }
            let size = subviews[element.index].sizeThatFits(proposed)
            allocations.append(.init(index: element.index, size: size))

            if let value = remaining, value.isFinite {
                let consumed = axis == .horizontal ? size.width : size.height
                remaining = max(0, value - consumed)
            }
            remainingCount -= 1
        }

        allocations.sort { $0.index < $1.index }
        return allocations
    }
}
