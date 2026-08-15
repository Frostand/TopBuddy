import Foundation

@MainActor
final class LockInStore: ObservableObject {
    @Published private(set) var activePolicy: LockInPolicy?
    @Published private(set) var grants: [LockInGrant] = []
    @Published var pendingAttempt: LockInAttempt?
    @Published private(set) var lastEvent = "Lock In is off."

    var isActive: Bool { activePolicy != nil }

    func configure(for block: ScheduleBlock) {
        let policy = LockInPolicy(block: block)
        if activePolicy != policy {
            grants = []
            pendingAttempt = nil
        }
        activePolicy = policy
        lastEvent = "Lock In is protecting \(block.title)."
    }

    func stop() {
        activePolicy = nil
        grants = []
        pendingAttempt = nil
        lastEvent = "Lock In ended."
    }

    func allowedBundleIdentifiers(at date: Date = Date()) -> Set<String> {
        cleanupExpired(at: date)
        let granted = grants.compactMap { grant -> String? in
            guard grant.targetKey.hasPrefix("application:") else { return nil }
            return String(grant.targetKey.dropFirst("application:".count))
        }
        let base = activePolicy?.allowedBundleIdentifiers ?? Set<String>()
        return base.union(granted)
    }

    func allows(url: URL, at date: Date = Date()) -> Bool {
        cleanupExpired(at: date)
        guard let policy = activePolicy else { return true }
        if policy.allows(url: url) { return true }
        guard let host = url.host else { return false }
        let candidate = LockInPolicy.canonicalHost(host)
        return grants.contains { grant in
            guard grant.targetKey.hasPrefix("website:") else { return false }
            let allowed = String(grant.targetKey.dropFirst("website:".count))
            return candidate == allowed || candidate.hasSuffix(".\(allowed)")
        }
    }

    @discardableResult
    func registerBlockedApplication(
        name: String,
        bundleIdentifier: String,
        at date: Date = Date()
    ) -> Bool {
        let attempt = LockInAttempt(
            kind: .application,
            label: name,
            value: bundleIdentifier,
            requestedAt: date
        )
        guard pendingAttempt?.targetKey != attempt.targetKey else { return false }
        pendingAttempt = attempt
        lastEvent = "Blocked \(name). Add a specific timed reason to use it."
        return true
    }

    @discardableResult
    func registerBlockedWebsite(url: URL, at date: Date = Date()) -> Bool {
        guard let host = url.host else { return false }
        let attempt = LockInAttempt(
            kind: .website,
            label: host,
            value: url.absoluteString,
            requestedAt: date
        )
        guard pendingAttempt?.targetKey != attempt.targetKey else { return false }
        pendingAttempt = attempt
        lastEvent = "Blocked \(host). Add a specific timed reason to visit it."
        return true
    }

    func grantPending(
        reason: String,
        durationMinutes: Int,
        at date: Date = Date()
    ) throws -> LockInAttempt {
        guard let attempt = pendingAttempt else {
            throw LockInReasonError.tooShort
        }
        let normalized = try LockInReasonValidator.validate(
            reason,
            durationMinutes: durationMinutes
        )
        let grant = LockInGrant(
            targetKey: attempt.targetKey,
            label: attempt.label,
            reason: normalized,
            expiresAt: date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        )
        grants.removeAll { $0.targetKey == grant.targetKey }
        grants.append(grant)
        pendingAttempt = nil
        lastEvent = "Allowed \(attempt.label) for \(durationMinutes) minutes."
        return attempt
    }

    func cancelPending() {
        if let pendingAttempt {
            lastEvent = "Kept \(pendingAttempt.label) blocked."
        }
        pendingAttempt = nil
    }

    func cleanupExpired(at date: Date = Date()) {
        let expiredLabels = grants.filter { $0.expiresAt <= date }.map(\.label)
        grants.removeAll { $0.expiresAt <= date }
        if !expiredLabels.isEmpty {
            lastEvent = "Expired access: \(expiredLabels.joined(separator: ", "))."
        }
    }
}
