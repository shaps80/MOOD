#if os(macOS)
import AppKit
import SwiftUI

extension View {
    func onScrollWheel(perform action: @escaping (CGFloat) -> Void) -> some View {
        overlay {
            ScrollWheelView(action: action)
                .accessibilityHidden(true)
        }
    }
}

private struct ScrollWheelView: NSViewRepresentable {
    let action: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollView {
        let view = ScrollView()
        view.action = action
        return view
    }

    func updateNSView(_ view: ScrollView, context: Context) {
        view.action = action
    }
}

private final class ScrollView: NSView {
    var action: ((CGFloat) -> Void)?
    private var eventMonitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        guard window != nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .scrollWheel
        ) { [weak self] event in
            guard
                let self,
                event.window === window,
                bounds.contains(convert(event.locationInWindow, from: nil))
            else {
                return event
            }

            action?(event.scrollingDeltaY)
            return nil
        }
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}
#else
import SwiftUI

extension View {
    func onScrollWheel(perform action: @escaping (CGFloat) -> Void) -> some View {
        self
    }
}
#endif
