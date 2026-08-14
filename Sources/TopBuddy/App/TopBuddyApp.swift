import AppKit
import SwiftUI

final class TopBuddyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct TopBuddyApp: App {
    @NSApplicationDelegateAdaptor(TopBuddyAppDelegate.self) private var appDelegate
    @StateObject private var model: AppModel

    init() {
        let appModel = AppModel()
        _model = StateObject(wrappedValue: appModel)
    }

    var body: some Scene {
        WindowGroup("TopBuddy", id: "main") {
            TopBuddyRootView()
                .environmentObject(model)
                .environmentObject(model.schedule)
                .task { model.startMonitoring() }
        }
        .defaultSize(width: 1_100, height: 760)

        Window("Workspace Hub", id: "workspace-hub") {
            WorkspaceHubView()
                .environmentObject(model)
                .environmentObject(model.schedule)
        }
        .defaultSize(width: 1_100, height: 760)

        MenuBarExtra("TopBuddy", systemImage: "pawprint.fill") {
            MenuBarView()
                .environmentObject(model)
                .environmentObject(model.schedule)
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }
    }
}
