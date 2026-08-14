import SwiftUI

struct NotchAgendaPageView: View {
    @EnvironmentObject private var schedule: ScheduleStore
    @ObservedObject var calendarAgenda: CalendarAgendaStore

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            dayPlan
                .frame(maxWidth: .infinity)
            appleCalendar
                .frame(maxWidth: .infinity)
        }
        .task { calendarAgenda.refresh() }
    }

    private var dayPlan: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("TOPBUDDY PLAN", systemImage: "list.bullet.rectangle.fill")
                .font(.caption2.weight(.black))
                .foregroundStyle(.cyan)
            ForEach(upcomingBlocks) { block in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: block.category.systemImage)
                        .foregroundStyle(schedule.isCompleted(block) ? .green : .white.opacity(0.55))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(block.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(block.timeLabel)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer()
                    if schedule.isCompleted(block) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                .padding(.vertical, 3)
            }
        }
        .notchAgendaCard()
    }

    private var appleCalendar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("APPLE CALENDAR", systemImage: "calendar.badge.clock")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.purple)
                Spacer()
                if calendarAgenda.canRead {
                    Button { calendarAgenda.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.plain)
                }
            }

            if calendarAgenda.canRead {
                if calendarAgenda.events.isEmpty {
                    Text("No events in the next 48 hours.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(calendarAgenda.events.prefix(5)) { event in
                        HStack(alignment: .top, spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple)
                                .frame(width: 3, height: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(event.isAllDay ? "All day · \(event.calendarTitle)" : event.startDate.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.48))
                            }
                        }
                    }
                }
            } else {
                Text("Calendar access is opt-in and read-only inside TopBuddy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Enable Calendar") { Task { await calendarAgenda.requestAccess() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .notchAgendaCard()
    }

    private var upcomingBlocks: [ScheduleBlock] {
        let currentID = schedule.currentBlock?.id
        let index = schedule.todayBlocks.firstIndex { $0.id == currentID } ?? 0
        return Array(schedule.todayBlocks.dropFirst(index).prefix(5))
    }
}
private extension View {
    func notchAgendaCard() -> some View {
        padding(12)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
    }
}
