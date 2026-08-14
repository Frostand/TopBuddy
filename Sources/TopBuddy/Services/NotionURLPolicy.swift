import Foundation

enum NotionURLPolicy {
    static let homeURL = URL(string: "https://www.notion.so/")!

    private static let notionDomains = ["notion.so", "notion.com", "notion.site"]

    static func notionURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              url.scheme?.lowercased() == "https",
              isNotionHost(url.host) else {
            return nil
        }
        return url
    }

    static func isNotionURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && isNotionHost(url.host)
    }

    static func allowsEmbeddedNavigation(to url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "about"
    }

    private static func isNotionHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return notionDomains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}
