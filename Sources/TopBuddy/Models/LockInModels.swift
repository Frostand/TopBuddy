import Foundation

struct LockInPolicy: Equatable, Sendable {
    let blockID: String
    let blockTitle: String
    let allowedBundleIdentifiers: Set<String>
    let allowedHosts: Set<String>
    let resources: [ResourceTarget]
    let materials: [StudyMaterial]

    init(
        block: ScheduleBlock,
        additionalAllowedBundleIdentifiers: Set<String> = []
    ) {
        blockID = block.id
        blockTitle = block.title
        resources = block.resources
        materials = block.materials
        allowedBundleIdentifiers = Set(
            block.resources
                .filter { $0.kind == .application }
                .map(\.value)
        ).union(additionalAllowedBundleIdentifiers)
        allowedHosts = Set(
            block.resources
                .filter { $0.kind == .url }
                .compactMap { URL(string: $0.value)?.host }
                .map(Self.canonicalHost)
        )
    }

    func allows(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "about" { return url.absoluteString == "about:blank" }
        guard (scheme == "https" || scheme == "http"), let host = url.host else { return false }
        let candidate = Self.canonicalHost(host)
        return allowedHosts.contains { allowed in
            candidate == allowed || candidate.hasSuffix(".\(allowed)")
        }
    }

    func allows(bundleIdentifier: String) -> Bool {
        allowedBundleIdentifiers.contains(bundleIdentifier)
    }

    static func canonicalHost(_ host: String) -> String {
        let value = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return value.hasPrefix("www.") ? String(value.dropFirst(4)) : value
    }
}

struct LockInAttempt: Identifiable, Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case application
        case website
    }

    let id = UUID()
    let kind: Kind
    let label: String
    let value: String
    let requestedAt: Date

    var targetKey: String {
        switch kind {
        case .application:
            return "application:\(value)"
        case .website:
            let host = URL(string: value)?.host ?? value
            return "website:\(LockInPolicy.canonicalHost(host))"
        }
    }
}

struct LockInGrant: Identifiable, Equatable, Sendable {
    let id = UUID()
    let targetKey: String
    let label: String
    let reason: String
    let expiresAt: Date
}
