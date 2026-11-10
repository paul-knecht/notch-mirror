import SwiftUI

// The content of the small settings window. It offers the same choices as
// the right-click menu, for the moments when neither the notch nor an
// icon is at hand (for example right after installing).
struct SettingsView: View {

    // Show the one-time hint at the top?
    let showsWelcome: Bool
    // Is there a notch to click right now?
    let notchAvailable: Bool
    let access: CameraAccess

    // The current choices. @State lets the controls change them.
    @State var trigger: Trigger
    @State var startAtLogin: Bool

    // What to do when the user changes something.
    let setTrigger: (Trigger) -> Void
    // Tries to switch "start at login" and returns how it is set afterwards.
    let setStartAtLogin: (Bool) -> Bool
    let openPrivacySettings: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsWelcome {
                Text(SettingsView.welcomeText(notchAvailable: notchAvailable))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Open from", selection: $trigger) {
                Text("Notch").tag(Trigger.notch)
                Text("Menu Bar Icon").tag(Trigger.menuBarIcon)
            }
            .pickerStyle(.radioGroup)
            .onChange(of: trigger) { _, newValue in
                setTrigger(newValue)
            }

            Toggle("Start at Login", isOn: $startAtLogin)
                .onChange(of: startAtLogin) { _, wanted in
                    // Show what macOS really did. If it refused, the
                    // switch goes back by itself.
                    let actual = setStartAtLogin(wanted)
                    if actual != wanted {
                        startAtLogin = actual
                    }
                }

            Text(SettingsView.accessText(access))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if access == .denied {
                Button("Open Privacy Settings", action: openPrivacySettings)
            }

            Divider()
            Button("Quit NotchMirror", action: quit)
        }
        .padding(20)
        .frame(width: 320)
    }

    // The one-time hint. Without a notch the menu bar icon is the way in.
    static func welcomeText(notchAvailable: Bool) -> String {
        let trigger = notchAvailable ? "the notch" : "the icon in the menu bar"
        return "Click \(trigger) to open the mirror. Right-click it for these settings."
    }

    // One line about whether the app may use the camera.
    static func accessText(_ access: CameraAccess) -> String {
        switch access {
        case .granted: return "Camera access: granted"
        case .notAsked: return "Camera access: not asked yet. macOS asks the first time you open the mirror."
        case .denied: return "Camera access: denied"
        }
    }
}
