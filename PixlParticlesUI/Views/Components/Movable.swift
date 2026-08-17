import SwiftUI

extension View {
    func draggableInspector<Content: View>(id: String = "inspector", isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) -> some View {
        modifier(MovableModifier(id: id, isPresented: isPresented, movableContent: content()))
    }
}

struct MovableModifier<MovableContent: View>: ViewModifier {
    @SceneStorage private var horizontalPosition: Double
    @SceneStorage private var verticalPosition: Double

    @State private var isVisible: Bool = false
    @State private var contentSize = CGSize.zero
    @State private var position: CGPoint?
    @State private var dragOrigin: CGPoint?

    @Binding var isPresented: Bool
    let movableContent: MovableContent

    init(id: String, isPresented: Binding<Bool>, movableContent: MovableContent) {
        self.movableContent = movableContent
        _horizontalPosition = .init(wrappedValue: 1, "\(id)-h")
        _verticalPosition = .init(wrappedValue: 0, "\(id)-v")
        _isPresented = isPresented
    }

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { geometry in
                let availableWidth = max(geometry.size.width - contentSize.width, 0)
                let availableHeight = max(geometry.size.height - contentSize.height, 0)
                let position =
                position
                ?? CGPoint(
                    x: horizontalPosition,
                    y: verticalPosition
                )
                let origin = CGPoint(
                    x: availableWidth * position.x,
                    y: geometry.size.height * position.y
                )

                ZStack(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        if isPresented && isVisible {
                            VStack {
                                Capsule()
                                    .glassEffect(.regular.interactive())
                                    .frame(width: 36, height: 5)
                                    .contentShape(.rect.inset(by: -10))
                                    .gesture(drag(in: geometry.size))

                                movableContent
                            }
                            .scenePadding()
                            .onGeometryChange(for: CGSize.self) { proxy in
                                proxy.size
                            } action: { size in
                                withAnimation(.snappy) {
                                    contentSize = size
                                }
                            }
                            .transition(PanelTransition())
                            .animation(.snappy, value: contentSize)
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
                }
                .animation(.bouncy, value: isPresented)
                .animation(.bouncy, value: isVisible)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // defers the presentation until we're actually on screen
                    isVisible = true
                }
            }
        }
    }

    private func drag(in containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin =
                    position
                    ?? CGPoint(
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

//#Preview {
//    ZStack {
//        Movable(
//            horizontalPosition: <#T##Binding<Double>#>,
//            verticalPosition: <#T##Binding<Double>#>,
//            isVisible: <#T##Bool#>,
//            content: <#T##() -> View#>
//        )
//    }
//    .frame(width: 600, height: 600)
//}
