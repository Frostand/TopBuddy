import Foundation

struct NotionBrowserCommand: Identifiable, Equatable {
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
final class NotionBrowserStore: ObservableObject {
    @Published var addressText: String
    @Published private(set) var pageTitle = "Notion"
    @Published private(set) var currentURL: URL
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var estimatedProgress = 0.0
    @Published private(set) var command: NotionBrowserCommand?
    @Published var errorMessage: String?

    private static let lastURLKey = "topbuddy.notion.last-url"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.lastURLKey).flatMap(NotionURLPolicy.notionURL(from:))
        let initial = saved ?? NotionURLPolicy.homeURL
        currentURL = initial
        addressText = initial.absoluteString
    }

    func goBack() { command = NotionBrowserCommand(action: .goBack) }
    func goForward() { command = NotionBrowserCommand(action: .goForward) }
    func reload() { command = NotionBrowserCommand(action: .reload) }
    func goHome() { requestLoad(NotionURLPolicy.homeURL) }

    func loadAddress() {
        guard let url = NotionURLPolicy.notionURL(from: addressText) else {
            errorMessage = "Enter a secure notion.so, notion.com, or notion.site address."
            return
        }
        requestLoad(url)
    }

    func requestLoad(_ url: URL) {
        errorMessage = nil
        addressText = url.absoluteString
        command = NotionBrowserCommand(action: .load(url))
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
            if NotionURLPolicy.isNotionURL(url) {
                defaults.set(url.absoluteString, forKey: Self.lastURLKey)
            }
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
}
