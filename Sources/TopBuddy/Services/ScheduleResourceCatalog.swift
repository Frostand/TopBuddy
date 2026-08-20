import Foundation

enum ScheduleResourceCatalog {
    static let notion = ResourceTarget.url("Notion", "https://www.notion.so/")
    static let terminal = ResourceTarget.application("Terminal", bundleIdentifier: "com.apple.Terminal")
    static let xcode = ResourceTarget.application("Xcode", bundleIdentifier: "com.apple.dt.Xcode")
    static let vscode = ResourceTarget.application("Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode")
    static let slack = ResourceTarget.application("Slack", bundleIdentifier: "com.tinyspeck.slackmacgap")
    static let zoom = ResourceTarget.application("Zoom", bundleIdentifier: "us.zoom.xos")

    static let templates: [ResourceTarget] = [
        notion, terminal, xcode, vscode, slack, zoom
    ]

    static func inferredResources(for title: String) -> [ResourceTarget] {
        let normalized = title.lowercased()
        if normalized.contains("code") || normalized.contains("program") || normalized.contains("develop") {
            return [terminal]
        }
        if normalized.contains("meeting") || normalized.contains("session") {
            return [zoom, slack]
        }
        if normalized.contains("notion") || normalized.contains("plan") || normalized.contains("research") {
            return [notion]
        }
        return []
    }

    static func inferredCategory(for title: String) -> BlockCategory {
        let normalized = title.lowercased()
        if normalized.contains("sleep") { return .sleep }
        if normalized.contains("breakfast") || normalized.contains("dinner") || normalized.contains("lunch") || normalized.contains("snack") { return .meal }
        if normalized.contains("commute") || normalized.contains("travel") { return .commute }
        if normalized.contains("school") || normalized.contains("class") { return .school }
        if normalized.contains("extracurricular") || normalized.contains("practice") { return .extracurricular }
        if normalized.contains("homework") || normalized.contains("assignment") { return .homework }
        if normalized.contains("research") { return .research }
        if normalized.contains("study") || normalized.contains("training") { return .competition }
        return .routine
    }

    static func inferredCompetition(for title: String) -> Competition? {
        let normalized = title.lowercased()
        guard normalized.contains("study") || normalized.contains("training") else { return nil }
        return Competition(rawValue: title)
    }
}
