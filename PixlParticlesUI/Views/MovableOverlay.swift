import SwiftUI

struct MovableOverlay<Content: View>: View {
    @Binding var horizontalPosition: Double
    @Binding var verticalPosition: Double
    @State private var contentSize = CGSize.zero
    @State private var position: CGPoint?
    @State private var dragOrigin: CGPoint?
    @ViewBuilder let content: Content

    init(
        horizontalPosition: Binding<Double>,
        verticalPosition: Binding<Double>,
        @ViewBuilder content: () -> Content
    ) {
        _horizontalPosition = horizontalPosition
        _verticalPosition = verticalPosition
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - contentSize.width, 0)
            let availableHeight = max(geometry.size.height - contentSize.height, 0)
            let position = position ?? CGPoint(
                x: horizontalPosition,
                y: verticalPosition
            )
            let origin = CGPoint(
                x: availableWidth * position.x,
                y: geometry.size.height * position.y
            )

            VStack(spacing: 0) {
                Capsule()
                    .glassEffect(.regular.interactive())
                    .frame(width: 36, height: 5)
                    .frame(width: 64, height: 28)
                    .contentShape(.rect)
                    .gesture(drag(in: geometry.size))

                    content
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                withAnimation(.snappy) {
                    contentSize = size
                }
            }
            .offset(
                x: clamped(
                    origin.x,
                    to: 0...availableWidth
                ),
                y: clamped(
                    origin.y,
                    to: 0...availableHeight
                )
            )
            .animation(.snappy, value: contentSize)
        }
    }

    private func drag(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = position ?? CGPoint(
                        x: horizontalPosition,
                        y: verticalPosition
                    )
                }
                guard let dragOrigin else { return }
                let availableWidth = max(containerSize.width - contentSize.width, 0)
                position = CGPoint(
                    x: normalized(
                        dragOrigin.x * availableWidth + value.translation.width,
                        within: availableWidth
                    ),
                    y: normalized(
                        dragOrigin.y * containerSize.height + value.translation.height,
                        within: containerSize.height
                    )
                )
            }
            .onEnded { _ in
                guard let position else { return }
                horizontalPosition = position.x
                verticalPosition = position.y
                dragOrigin = nil
            }
    }

    private func normalized(_ value: Double, within extent: Double) -> Double {
        guard extent > 0 else { return 0 }
        return clamped(value / extent, to: 0...1)
    }

    private func clamped<T: Comparable>(
        _ value: T,
        to range: ClosedRange<T>
    ) -> T {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
