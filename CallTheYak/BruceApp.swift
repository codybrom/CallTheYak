import SwiftUI

@main
struct BruceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            Button("Call the Yak") {
                YakManager.shared.callTheYak()
            }
            .keyboardShortcut("y", modifiers: [.command, .shift])

            Divider()

            Button("Settings...") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }

            Divider()

            Button("Quit Bruce") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            let image = NSImage(named: "MenuBarIcon")
            if let image {
                Image(nsImage: image)
            } else {
                Image(systemName: "hare.fill")
            }
        }

        Window("Call the Yak", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Trigger Bruce's first appearance shortly after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            YakManager.shared.callTheYak()
        }
    }
}
