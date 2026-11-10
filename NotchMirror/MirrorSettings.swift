import Foundation

// The two ways the mirror can be opened.
enum Trigger: String {
    case notch          // by clicking the notch
    case menuBarIcon    // by clicking an icon in the menu bar
}

// What the app remembers between launches. The values live in the app's
// preferences (UserDefaults), which macOS keeps on disk.
struct MirrorSettings {

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // How the mirror is opened. Anything unknown counts as "notch".
    var trigger: Trigger {
        get { Trigger(rawValue: defaults.string(forKey: "trigger") ?? "") ?? .notch }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "trigger") }
    }

    // True once the first-launch hint has been shown.
    var didShowWelcome: Bool {
        get { defaults.bool(forKey: "didShowWelcome") }
        nonmutating set { defaults.set(newValue, forKey: "didShowWelcome") }
    }

    // True once the app has added itself to the login items.
    var didSetUpLoginItem: Bool {
        get { defaults.bool(forKey: "didSetUpLoginItem") }
        nonmutating set { defaults.set(newValue, forKey: "didSetUpLoginItem") }
    }

    // Is the menu bar icon shown? Always in icon mode. In notch mode only
    // when no screen has a notch, so the app stays reachable.
    static func showsMenuBarIcon(trigger: Trigger, notchAvailable: Bool) -> Bool {
        trigger == .menuBarIcon || !notchAvailable
    }

    // Does the notch react to clicks? Only in notch mode, with a notch.
    static func showsNotchArea(trigger: Trigger, notchAvailable: Bool) -> Bool {
        trigger == .notch && notchAvailable
    }
}
