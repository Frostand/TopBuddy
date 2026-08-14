import EventKit
import Foundation

@MainActor
final class CalendarAgendaStore: ObservableObject {
    @Published private(set) var authorizationStatus: EKAuthorizationStatus
    @Published private(set) var isEnabled: Bool
    @Published private(set) var events: [AgendaEvent] = []
    @Published var errorMessage: String?

    private static let enabledKey = "topbuddy.calendar.enabled"
    private let eventStore: EKEventStore
    private let calendar: Calendar
    private let defaults: UserDefaults

    init(
        eventStore: EKEventStore = EKEventStore(),
        calendar: Calendar = .autoupdatingCurrent,
        defaults: UserDefaults = .standard
    ) {
        self.eventStore = eventStore
        self.calendar = calendar
        self.defaults = defaults
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        if canRead { refresh() }
    }

    var canRead: Bool {
        isEnabled && authorizationStatus == .fullAccess
    }

    func requestAccess() async {
        do {
            if authorizationStatus != .fullAccess {
                _ = try await eventStore.requestFullAccessToEvents()
            }
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            isEnabled = authorizationStatus == .fullAccess
            defaults.set(isEnabled, forKey: Self.enabledKey)
            if canRead { refresh() }
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            isEnabled = false
            defaults.set(false, forKey: Self.enabledKey)
            errorMessage = error.localizedDescription
        }
    }

    func disable() {
        isEnabled = false
        defaults.set(false, forKey: Self.enabledKey)
        events = []
        errorMessage = nil
    }

    func refresh(now: Date = Date()) {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard canRead else {
            events = []
            return
        }
        guard let end = calendar.date(byAdding: .day, value: 2, to: now) else { return }
        let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: nil)
        events = eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(12)
            .map {
                AgendaEvent(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    title: $0.title?.isEmpty == false ? $0.title : "Untitled event",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    calendarTitle: $0.calendar.title,
                    isAllDay: $0.isAllDay
                )
            }
        errorMessage = nil
    }
}
