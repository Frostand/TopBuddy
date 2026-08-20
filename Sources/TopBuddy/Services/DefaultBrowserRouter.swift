import AppKit
import Foundation

/// The browser macOS currently associates with HTTP(S) links.
///
/// TopBuddy deliberately keeps this identity small: it is used only to open
/// approved links and preserve that browser in the Lock In app allowlist. It
/// never reads tabs, history, cookies, or login state.
struct DefaultBrowserIdentity: Equatable, Sendable {
    let name: String
    let bundleIdentifier: String
}

@MainActor
protocol DefaultBrowserRouting: AnyObject {
    var currentBrowser: DefaultBrowserIdentity { get }
    @discardableResult
    func open(_ url: URL) -> Bool
}

@MainActor
final class SystemDefaultBrowserRouter: DefaultBrowserRouting {
    private let workspace: NSWorkspace
    private let probeURL = URL(string: "https://example.com")!

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    var currentBrowser: DefaultBrowserIdentity {
        guard let applicationURL = workspace.urlForApplication(toOpen: probeURL) else {
            return DefaultBrowserIdentity(name: "Default browser", bundleIdentifier: "")
        }

        let name = FileManager.default.displayName(atPath: applicationURL.path)
            .replacingOccurrences(of: ".app", with: "", options: [.caseInsensitive, .backwards])
        let bundleIdentifier = Bundle(url: applicationURL)?.bundleIdentifier ?? ""
        return DefaultBrowserIdentity(
            name: name.isEmpty ? "Default browser" : name,
            bundleIdentifier: bundleIdentifier
        )
    }

    @discardableResult
    func open(_ url: URL) -> Bool {
        workspace.open(url)
    }
}
