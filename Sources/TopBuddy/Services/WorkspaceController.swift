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
    let defaultBrowserRouter: any DefaultBrowserRouting
    private let protectedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.loginwindow",
        "com.apple.notificationcenterui",
        "com.apple.controlcenter",
        "com.frostand.TopBuddy"
    ]

    init(
        workspace: NSWorkspace = .shared,
        defaultBrowserRouter: (any DefaultBrowserRouting)? = nil
    ) {
        self.workspace = workspace
        self.defaultBrowserRouter = defaultBrowserRouter ?? SystemDefaultBrowserRouter(workspace: workspace)
        refreshRunningApps()
    }

    var currentDefaultBrowser: DefaultBrowserIdentity {
        defaultBrowserRouter.currentBrowser
    }

    /// Returns the apps needed to carry out this block. A web block keeps the
    /// current macOS default browser available; TopBuddy never assumes which
    /// browser that is.
    func allowedBundleIdentifiers(for block: ScheduleBlock) -> Set<String> {
        var bundleIdentifiers = Set(
            block.resources
                .filter { $0.kind == .application }
                .map(\.value)
        )
        let hasSafeURL = block.resources.contains { $0.kind == .url && $0.isSafeToOpen }
        let browserBundleIdentifier = currentDefaultBrowser.bundleIdentifier
        if hasSafeURL, !browserBundleIdentifier.isEmpty {
            bundleIdentifiers.insert(browserBundleIdentifier)
        }
        return bundleIdentifiers
    }

    func prepare(
        block: ScheduleBlock,
        hideDistractions: Bool,
        strictAllowlist: Bool = false
    ) {
        let requiredBundleIDs = allowedBundleIdentifiers(for: block)
        if hideDistractions {
            hideUnrelatedApps(
                keeping: requiredBundleIDs,
                preserveCoachApps: !strictAllowlist
            )
        }
        let openingResources = block.resources.filter(\.openAtStart)
        open(openingResources)
        lastActionSummary = openingResources.isEmpty
            ? "Focus started. No resources were set to open automatically."
            : "Opened \(openingResources.count) resource\(openingResources.count == 1 ? "" : "s") for \(block.title)."
        refreshRunningApps()
    }

    func open(_ resources: [ResourceTarget]) {
        for resource in resources {
            guard resource.isSafeToOpen else { continue }
            switch resource.kind {
            case .url:
                guard let url = URL(string: resource.value) else { continue }
                _ = defaultBrowserRouter.open(url)
            case .application:
                openApplication(bundleIdentifier: resource.value)
            }
        }
    }

    func hideUnrelatedApps(
        keeping requiredBundleIDs: Set<String> = [],
        preserveCoachApps: Bool = true
    ) {
        let allowed = protectedBundleIDs.union(requiredBundleIDs)
        for app in workspace.runningApplications where app.activationPolicy == .regular {
            guard !isProtected(
                app,
                additionalAllowed: allowed,
                preserveCoachApps: preserveCoachApps
            ) else { continue }
            _ = app.hide()
        }
        lastActionSummary = "Hid unrelated apps. Nothing was quit."
        refreshRunningApps()
    }

    func blockFrontmostApplication(
        keeping requiredBundleIDs: Set<String>
    ) -> RunningAppInfo? {
        guard let app = workspace.frontmostApplication,
              app.activationPolicy == .regular,
              !app.isTerminated,
              let bundleID = app.bundleIdentifier,
              !isProtected(
                  app,
                  additionalAllowed: requiredBundleIDs,
                  preserveCoachApps: false
              ) else { return nil }
        let info = RunningAppInfo(
            processIdentifier: app.processIdentifier,
            bundleIdentifier: bundleID,
            name: app.localizedName ?? bundleID
        )
        _ = app.hide()
        lastActionSummary = "Lock In hid \(info.name). Nothing was quit."
        refreshRunningApps()
        return info
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
        additionalAllowed: Set<String>,
        preserveCoachApps: Bool = true
    ) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return true }
        if protectedBundleIDs.contains(bundleID) || additionalAllowed.contains(bundleID) {
            return true
        }
        let lowercaseID = bundleID.lowercased()
        let isCoachApp = lowercaseID.contains("openai") || lowercaseID.contains("chatgpt")
        return app == .current || (preserveCoachApps && isCoachApp)
    }
}
