import AppKit

// Ties the app together: the click area on the notch, the menu bar icon,
// the mirror panel and the camera.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // True while the automated tests run. Then the app must leave the
    // camera, the login items and other running copies alone.
    let isRunningTests =
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    // What the app remembers between launches. The tests get their own
    // throwaway preferences, so they never change the real ones.
    lazy var settings: MirrorSettings = {
        guard isRunningTests else { return MirrorSettings() }
        let suite = "local.notchmirror.tests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return MirrorSettings(defaults: defaults)
    }()

    // The icon in the menu bar (shown only in icon mode).
    var statusItem: NSStatusItem!

    // The invisible click area on the notch (shown only in notch mode).
    let clickArea = NotchClickArea()

    let panel = MirrorPanel()
    let camera = MirrorCamera()

    // Decides what happens on open and close.
    var logic = MirrorLogic()

    // The small settings window, while it is open.
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The menu bar icon: left click toggles the mirror, right click
        // shows the menu.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "person.crop.square",
                                   accessibilityDescription: "NotchMirror")
            button.target = self
            button.action = #selector(iconClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        clickArea.onClick = { [weak self] in self?.toggleMirror() }
        clickArea.menuProvider = { [weak self] in self?.buildMenu() ?? NSMenu() }

        panel.setPreviewLayer(camera.previewLayer)
        panel.onOpenPrivacySettings = { [weak self] in self?.openPrivacySettings() }

        applyVisibility(notchScreen: currentNotchScreen())

        if isRunningTests { return }

        // Only one copy may run; this one replaces any older copy.
        SingleInstance.quitOlderCopies()

        // The first time an installed copy runs, add it to the login items.
        if LoginItem.shouldEnableAutomatically(bundlePath: Bundle.main.bundlePath,
                                               alreadyDone: settings.didSetUpLoginItem) {
            // Remember it only if it worked, so a failed try is repeated next time.
            if LoginItem.setEnabled(true) {
                settings.didSetUpLoginItem = true
            }
        }

        watchForReasonsToClose()
    }

    func applicationWillTerminate(_ notification: Notification) {
        closeMirror()
    }

    // MARK: - What is visible

    // The screen with the notch, if there is one right now.
    func currentNotchScreen() -> ScreenInfo? {
        NotchGeometry.notchScreen(NSScreen.screens.map(ScreenInfo.init))
    }

    // Shows the menu bar icon or the click area on the notch, depending
    // on the setting and on whether there is a notch at all.
    func applyVisibility(notchScreen: ScreenInfo?) {
        let trigger = settings.trigger
        let available = notchScreen != nil

        statusItem.isVisible = MirrorSettings.showsMenuBarIcon(trigger: trigger, notchAvailable: available)

        if MirrorSettings.showsNotchArea(trigger: trigger, notchAvailable: available),
           let screen = notchScreen, let notch = NotchGeometry.notchRect(screen) {
            clickArea.place(over: notch)
            clickArea.orderFrontRegardless()
        } else {
            clickArea.orderOut(nil)
        }
    }

    // Changes how the mirror is opened, and remembers it.
    func setTrigger(_ trigger: Trigger) {
        settings.trigger = trigger
        applyVisibility(notchScreen: currentNotchScreen())
    }

    // MARK: - Opening and closing

    // Opens the mirror if it is closed, and closes it if it is open.
    func toggleMirror() {
        if logic.isOpen {
            closeMirror()
            return
        }
        // The tests pretend that access is granted and a camera exists;
        // the camera itself is never started by them (see perform).
        let access = isRunningTests ? .granted : camera.access
        let hasCamera = isRunningTests ? true : camera.hasCamera
        perform(logic.open(access: access, hasCamera: hasCamera))
    }

    func closeMirror() {
        perform(logic.close())
    }

    // Carries out what MirrorLogic decided.
    func perform(_ actions: [MirrorAction]) {
        for action in actions {
            switch action {
            case .showPanel(let content):
                panel.show(content)
                panel.open(on: screenForPanel(), animated: !isRunningTests)
            case .updatePanel(let content):
                panel.show(content)
            case .hidePanel:
                panel.close(animated: !isRunningTests) {}
            case .askForAccess:
                if isRunningTests { continue }
                camera.askForAccess { [weak self] granted in
                    guard let self else { return }
                    self.perform(self.logic.accessAnswered(granted: granted,
                                                           hasCamera: self.camera.hasCamera))
                }
            case .startCamera:
                if !isRunningTests { camera.start() }
            case .stopCamera:
                if !isRunningTests { camera.stop() }
            }
        }
    }

    // The panel goes to the screen with the notch, because that is where
    // the camera is. Without a notch it uses the main screen.
    private func screenForPanel() -> ScreenInfo {
        if let notchScreen = currentNotchScreen() { return notchScreen }
        if let main = NSScreen.main ?? NSScreen.screens.first { return ScreenInfo(main) }
        return ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                          safeTop: 0, topLeft: nil, topRight: nil)
    }

    // Everything besides the trigger that closes the mirror.
    private func watchForReasonsToClose() {
        // The esc key, while the panel has the keyboard.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.logic.isOpen, event.keyCode == 53 else { return event }
            self.closeMirror()
            return nil   // "handled, don't pass it on"
        }

        // A click anywhere outside NotchMirror.
        // (A "global monitor" hears clicks that go to other apps.)
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.logic.closesOnOutsideClick else { return }
                self.closeMirror()
            }
        }

        // The Mac goes to sleep, or the screen is locked.
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            workspace.addObserver(self, selector: #selector(closeForSystemEvent), name: name, object: nil)
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(closeForSystemEvent),
            name: Notification.Name("com.apple.screenIsLocked"), object: nil)

        // A display was connected, removed or rearranged: close, and move
        // the click area to where the notch is now.
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func closeForSystemEvent() {
        closeMirror()
    }

    @objc private func screensChanged() {
        closeMirror()
        applyVisibility(notchScreen: currentNotchScreen())
    }

    // MARK: - Menu

    // Called for every click on the menu bar icon.
    @objc private func iconClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            // Attach the menu just long enough to show it. If it stayed
            // attached, left clicks would open it too.
            statusItem.menu = buildMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleMirror()
        }
    }

    // The menu shown on a right click, on the icon and on the notch.
    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        // Don't grey out items by itself; we decide that.
        menu.autoenablesItems = false

        let header = NSMenuItem(title: "Open from", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let notch = NSMenuItem(title: "Notch", action: #selector(chooseNotch), keyEquivalent: "")
        let icon = NSMenuItem(title: "Menu Bar Icon", action: #selector(chooseMenuBarIcon), keyEquivalent: "")
        notch.state = settings.trigger == .notch ? .on : .off
        icon.state = settings.trigger == .menuBarIcon ? .on : .off
        for item in [notch, icon] {
            item.target = self
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NotchMirror",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func chooseNotch() { setTrigger(.notch) }
    @objc private func chooseMenuBarIcon() { setTrigger(.menuBarIcon) }

    @objc private func toggleStartAtLogin() {
        LoginItem.setEnabled(!LoginItem.isEnabled)
    }

    // MARK: - Privacy settings

    // Opens System Settings > Privacy & Security > Camera.
    func openPrivacySettings() {
        let address = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        if let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        }
    }
}
