import SwiftUI

public extension Transition where Self == PanelTransition {
    static var panel: Self { .init(anchor: .top) }
    static func panel(anchor: UnitPoint) -> Self {
        .init(anchor: anchor)
    }
}

public struct PanelTransition: Transition {
    let anchor: UnitPoint

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.94, anchor: anchor)
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 8)
    }
}
