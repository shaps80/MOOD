@preconcurrency import AppKit
import SwiftUI

@MainActor
final class ApplicationRuntime: NSObject {
    private var window: NSWindow?

    func start() {
        let application = NSApplication.shared
        application.delegate = self
        application.setActivationPolicy(.regular)
        application.mainMenu = makeMainMenu()

        let contentRect = NSRect(
            origin: .zero,
            size: NSSize(width: 1024, height: 720)
        )
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Pixl Particles"
        window.contentView = NSHostingView(rootView: ContentView())
        window.delegate = self

        self.window = window

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit Pixl Particles",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        quitItem.target = NSApplication.shared
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)

        return mainMenu
    }
}

extension ApplicationRuntime: NSApplicationDelegate {}

extension ApplicationRuntime: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared.terminate(nil)
    }
}
