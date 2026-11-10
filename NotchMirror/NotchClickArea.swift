import AppKit

// An invisible window that sits exactly on the notch and reacts to clicks.
//
// It is 1% black, which nobody can see. It must not be 0%: macOS lets
// clicks fall through fully transparent windows, but hands them to a
// window that is even slightly visible.
final class NotchClickArea: NSPanel {

    // Called on a left click.
    var onClick: (() -> Void)? {
        get { clickView.onClick }
        set { clickView.onClick = newValue }
    }

    // Supplies the menu shown on a right click.
    var menuProvider: (() -> NSMenu)? {
        get { clickView.menuProvider }
        set { clickView.menuProvider = newValue }
    }

    private let clickView = ClickView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        // Above the menu bar, and one level above the mirror panel: the
        // open panel covers the notch, and a click on the notch must still
        // reach this window to close the mirror again.
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 4)
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = NSColor.black.withAlphaComponent(0.01)
        isOpaque = false
        hasShadow = false
        // Present on every Space (desktop), also over full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = clickView
    }

    // Moves the window onto the notch.
    func place(over notch: CGRect) {
        setFrame(NotchGeometry.clickRect(notch: notch), display: true)
    }
}

// The view inside the click area. It turns mouse clicks into the two calls.
private final class ClickView: NSView {

    var onClick: (() -> Void)?
    var menuProvider: (() -> NSMenu)?

    // React to the very first click, even though the app is in the background.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseUp(with event: NSEvent) {
        // A click with the control key held counts as a right click.
        if event.modifierFlags.contains(.control) {
            showMenu(with: event)
        } else {
            onClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        showMenu(with: event)
    }

    private func showMenu(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}
