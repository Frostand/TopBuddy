import AppKit
import Foundation

struct RunningAppInfo: Identifiable, Hashable, Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: String
    let name: String

    var id: String { "\(bundleIdentifier)|\(processIdentifier)" }
}

@MainActor
final class WorkspaceController: ObservableObject {
    @Published private(set) var runningApps: [RunningAppInfo] = []
    @Published private(set) var lastActionSummary = ""

    private let workspace: NSWorkspace
    private let protectedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.loginwindow",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.frostand.TopBuddy"
    ]

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        refreshRunningApps()
    }

    func prepare(block: ScheduleBlock, hideDistractions: Bool) {
        let requiredBundleIDs = Set(
            block.resources
                .filter { $0.kind == .application }
                .map(\.value)
        )
        if hideDistractions {
            hideUnrelatedApps(keeping: requiredBundleIDs)
        }
        open(block.resources)
        lastActionSummary = block.resources.isEmpty
            ? "Focus started. This block has no external resources."
            : "Opened \(block.resources.count) resource\(block.resources.count == 1 ? "" : "s") for \(block.title)."
        refreshRunningApps()
    }

    func open(_ resources: [ResourceTarget]) {
        for resource in resources {
            guard resource.isSafeToOpen else { continue }
            switch resource.kind {
            case .url:
                guard let url = URL(string: resource.value) else { continue }
                workspace.open(url)
            case .application:
                openApplication(bundleIdentifier: resource.value)
            }
        }
    }

    func hideUnrelatedApps(keeping requiredBundleIDs: Set<String> = []) {
        let allowed = protectedBundleIDs.union(requiredBundleIDs)
        for app in workspace.runningApplications where app.activationPolicy == .regular {
            guard !isProtected(app, additionalAllowed: allowed) else { continue }
            _ = app.hide()
        }
        lastActionSummary = "Hid unrelated apps. Nothing was quit."
        refreshRunningApps()
    }

    /// Requests normal app termination. Never uses forceTerminate().
    /// The target app remains responsible for prompting about unsaved documents.
    func requestGracefulQuit(bundleIdentifiers: Set<String>) -> [String] {
        var requested: [String] = []
        for app in workspace.runningApplications {
            guard let bundleID = app.bundleIdentifier,
                  bundleIdentifiers.contains(bundleID),
                  !isProtected(app, additionalAllowed: []) else { continue }
            if app.terminate() {
                requested.append(app.localizedName ?? bundleID)
            }
        }
        lastActionSummary = requested.isEmpty
            ? "No quit requests were sent."
            : "Requested a normal quit from: \(requested.joined(separator: ", "))."
        refreshRunningApps()
        return requested
    }

    func refreshRunningApps() {
        runningApps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier,
                      !isProtected(app, additionalAllowed: []) else { return nil }
                return RunningAppInfo(
                    processIdentifier: app.processIdentifier,
                    bundleIdentifier: bundleID,
                    name: app.localizedName ?? bundleID
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func openApplication(bundleIdentifier: String) {
        guard let applicationURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            lastActionSummary = "Could not find an installed app with bundle ID \(bundleIdentifier)."
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: applicationURL, configuration: configuration) { _, error in
            if let error {
                NSLog("TopBuddy could not open %@: %@", bundleIdentifier, error.localizedDescription)
            }
        }
    }

    private func isProtected(
        _ app: NSRunningApplication,
        additionalAllowed: Set<String>
    ) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return true }
        if protectedBundleIDs.contains(bundleID) || additionalAllowed.contains(bundleID) {
            return true
        }
        let lowercaseID = bundleID.lowercased()
        return lowercaseID.contains("openai") || lowercaseID.contains("chatgpt") || app == .current
    }
}
