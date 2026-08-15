import Foundation

struct FocusBrowserCommand: Identifiable, Equatable {
    enum Action: Equatable {
        case goBack
        case goForward
        case reload
        case load(URL)
    }

    let id = UUID()
    let action: Action
}

@MainActor
final class FocusBrowserStore: ObservableObject {
    @Published var addressText = ""
    @Published private(set) var pageTitle = "Lock In Browser"
    @Published private(set) var currentURL = URL(string: "about:blank")!
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var estimatedProgress = 0.0
    @Published private(set) var command: FocusBrowserCommand?
    @Published private(set) var blockTitle = "No active block"
    @Published private(set) var webResources: [ResourceTarget] = []
    @Published private(set) var materials: [StudyMaterial] = []
    @Published var errorMessage: String?

    let lockIn: LockInStore

    init(lockIn: LockInStore) {
        self.lockIn = lockIn
    }

    func configure(for block: ScheduleBlock) {
        blockTitle = block.title
        webResources = block.resources.filter { $0.kind == .url }
        materials = block.materials
        lockIn.configure(for: block)
        resetToBlank()
        if let first = webResources.first(where: \.openAtStart),
           let url = URL(string: first.value) {
            requestLoad(url)
        }
    }

    func goBack() { command = FocusBrowserCommand(action: .goBack) }
    func goForward() { command = FocusBrowserCommand(action: .goForward) }
    func reload() { command = FocusBrowserCommand(action: .reload) }

    func loadAddress() {
        let trimmed = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = secureURL(from: trimmed) else {
            errorMessage = "Enter a secure HTTPS address or a localhost development URL."
            return
        }
        requestLoad(url)
    }

    func requestLoad(_ resource: ResourceTarget) {
        guard resource.kind == .url, let url = URL(string: resource.value) else { return }
        requestLoad(url)
    }

    func requestLoad(_ url: URL) {
        guard isSafe(url) else {
            errorMessage = "Lock In Browser accepts HTTPS and localhost URLs only."
            return
        }
        guard lockIn.allows(url: url) else {
            lockIn.registerBlockedWebsite(url: url)
            errorMessage = "\(url.host ?? "This site") is outside this block's focus kit."
            return
        }
        errorMessage = nil
        addressText = url.absoluteString
        command = FocusBrowserCommand(action: .load(url))
    }

    func allowsNavigation(to url: URL) -> Bool {
        if url.absoluteString == "about:blank" { return true }
        guard isSafe(url), lockIn.allows(url: url) else {
            lockIn.registerBlockedWebsite(url: url)
            errorMessage = "Navigation stopped because this domain is not assigned to \(blockTitle)."
            return false
        }
        errorMessage = nil
        return true
    }

    func resumeAfterGrant(_ attempt: LockInAttempt) {
        guard attempt.kind == .website,
              let pendingURL = secureURL(from: attempt.value)
        else { return }
        requestLoad(pendingURL)
    }

    func enforceCurrentAccess(at date: Date = Date()) {
        guard currentURL.absoluteString != "about:blank",
              !lockIn.allows(url: currentURL, at: date) else { return }
        resetToBlank()
        errorMessage = "Temporary website access expired. The protected browser returned to a blank page."
    }

    func update(
        url: URL?,
        title: String?,
        canGoBack: Bool,
        canGoForward: Bool,
        isLoading: Bool
    ) {
        if let url {
            currentURL = url
            addressText = url.absoluteString
        }
        if let title, !title.isEmpty { pageTitle = title }
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isLoading = isLoading
        if !isLoading { estimatedProgress = 1 }
    }

    func updateProgress(_ value: Double) {
        estimatedProgress = min(1, max(0, value))
    }

    func report(error: Error) {
        errorMessage = error.localizedDescription
        isLoading = false
    }

    private func secureURL(from value: String) -> URL? {
        if let url = URL(string: value), url.scheme != nil { return isSafe(url) ? url : nil }
        guard let url = URL(string: "https://\(value)") else { return nil }
        return isSafe(url) ? url : nil
    }

    private func isSafe(_ url: URL) -> Bool {
        guard let host = url.host, let scheme = url.scheme?.lowercased(),
              url.user == nil, url.password == nil else { return false }
        if scheme == "https" { return true }
        return scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)
    }

    private func resetToBlank() {
        let blank = URL(string: "about:blank")!
        currentURL = blank
        addressText = ""
        pageTitle = "Lock In Browser"
        canGoBack = false
        canGoForward = false
        isLoading = false
        errorMessage = nil
        command = FocusBrowserCommand(action: .load(blank))
    }
}
