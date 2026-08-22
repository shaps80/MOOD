import SwiftUI

extension PanelView {
    internal struct ContentView: View {
        @State private var contentSize = CGSize.zero
        @State private var position: CGPoint?
        @State private var dragOrigin: CGPoint?

        let subview: Subview
        let containerSize: CGSize
        @Binding var customization: PanelCustomization<ID>

        init(subview: Subview, containerSize: CGSize, customization: Binding<PanelCustomization<ID>>) {
            self.subview = subview
            self.containerSize = containerSize
            _customization = customization
        }

        var body: some View {
            if let id = subview.containerValues.tag(for: ID.self) {
                let isExplicitlyHidden = customization[visibility: id] == .hidden
                let isVisibleByDefault = subview.containerValues.panelDefaultVisibility != .hidden
                let defaultPlacement = subview.containerValues.panelDefaultPlacement

                if !isExplicitlyHidden && isVisibleByDefault {
                    let availableWidth = max(containerSize.width - contentSize.width, 0)
                    let availableHeight = max(containerSize.height - contentSize.height, 0)

                    let position = position
                    ?? CGPoint(
                        x: customization.placement[id]?.x ?? defaultPlacement.x,
                        y: customization.placement[id]?.y ?? defaultPlacement.y
                    )
                    let origin = CGPoint(
                        x: availableWidth * position.x,
                        y: availableHeight * position.y
                    )

                    let widths = subview.containerValues.panelWidths

                    VStack {
                        Capsule()
                            .glassEffect(.regular.interactive())
                            .frame(width: 36, height: 5)
                            .contentShape(.rect.inset(by: -10))
                            .gesture(drag(id: id, in: containerSize, defaultPlacement: defaultPlacement))
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    customization[visibility: id] = .hidden
                                }
                            )

                        subview
                            .clipShape(.rect(cornerRadius: 28))
                            .glassEffect(.regular, in: .rect(cornerRadius: 28))
                            .frame(
                                minWidth: widths.min,
                                idealWidth: widths.ideal,
                                maxWidth: widths.max
                            )
                    }
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { size in
                        withAnimation(.smooth.speed(2)) {
                            contentSize = size
                        }
                    }
                    .transition(PanelTransition())
                    .animation(.smooth.speed(2), value: contentSize)
                    .offset(
                        x: clamped(origin.x, to: 0...availableWidth),
                        y: clamped(origin.y, to: 0...availableHeight)
                    )
                }
            }
        }

        private func drag(id: ID, in containerSize: CGSize, defaultPlacement: UnitPoint) -> some Gesture {
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    if dragOrigin == nil {
                        dragOrigin =
                        position
                        ?? CGPoint(
                            x: customization.placement[id]?.x ?? defaultPlacement.x,
                            y: customization.placement[id]?.y ?? defaultPlacement.y
                        )
                    }
                    guard let dragOrigin else { return }
                    let availableWidth = max(containerSize.width - contentSize.width, 0)
                    let availableHeight = max(containerSize.height - contentSize.height, 0)
                    position = CGPoint(
                        x: normalized(
                            dragOrigin.x * availableWidth + value.translation.width,
                            within: availableWidth
                        ),
                        y: normalized(
                            dragOrigin.y * availableHeight + value.translation.height,
                            within: availableHeight
                        )
                    )
                }
                .onEnded { _ in
                    guard let position else { return }
                    customization.placement[id] = .init(x: position.x, y: position.y)
                    dragOrigin = nil
                }
        }

        private func normalized(_ value: Double, within extent: Double) -> Double {
            guard extent > 0 else { return 0 }
            return clamped(value / extent, to: 0...1)
        }

        private func clamped<T: Comparable>(_ value: T, to range: ClosedRange<T>) -> T {
            min(max(value, range.lowerBound), range.upperBound)
        }
    }
}
