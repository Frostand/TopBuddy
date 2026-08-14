import SwiftUI

struct CurrentBlockCard: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var schedule: ScheduleStore

    let block: ScheduleBlock
    let isCurrent: Bool
    let editResources: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Label(block.category.rawValue.capitalized, systemImage: block.category.systemImage)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                if isCurrent {
                    PetStatusBadge(text: "Current", color: .blue, systemImage: "circle.fill")
                } else if schedule.isCompleted(block) {
                    PetStatusBadge(text: "Completed", color: .green, systemImage: "checkmark")
                }
                Spacer()
                Text(block.timeLabel)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(block.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .textSelection(.enabled)

                if isCurrent {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(countdown(for: block, at: context.date))
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(.tint)
                                Spacer()
                                Text(progressLabel(for: block, at: context.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: progress(for: block, at: context.date))
                                .tint(schedule.petState.accent)
                                .accessibilityLabel("Block progress")
                                .accessibilityValue(progressLabel(for: block, at: context.date))
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                PetSectionLabel(title: "Exact actions", systemImage: "list.bullet.rectangle")
                Text(block.exactActions)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 7) {
                PetSectionLabel(title: "Finish line", systemImage: "flag.checkered")
                Text(block.finishTarget)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.09), in: RoundedRectangle(cornerRadius: PetDesign.compactRadius))

            resources

            HStack(spacing: 10) {
                Button("Start block", systemImage: "play.fill") {
                    model.start(block)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: [.command])

                Button("Hide distractions", systemImage: "eye.slash") {
                    model.hideDistractions(for: block)
                }
                .controlSize(.large)

                Spacer()

                Button(
                    schedule.isCompleted(block) ? "Reopen" : "Mark done",
                    systemImage: schedule.isCompleted(block) ? "arrow.uturn.backward" : "checkmark"
                ) {
                    model.toggleCompletion(block)
                }
                .controlSize(.large)
            }
        }
        .petSurface(padding: 20)
    }

    private var resources: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PetSectionLabel(title: "Focus kit", systemImage: "square.grid.2x2")
                Spacer()
                Button("Edit", action: editResources)
                    .buttonStyle(.link)
                    .controlSize(.small)
            }

            if block.resources.isEmpty {
                Text("No apps or sites assigned to this block.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(block.resources) { resource in
                            Button {
                                model.workspace.open([resource])
                            } label: {
                                Label(resource.label, systemImage: resource.kind == .url ? "link" : "app")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private func progress(for block: ScheduleBlock, at date: Date) -> Double {
        let duration = max(1, Double(block.durationMinutes * 60))
        return min(1, max(0, (duration - schedule.secondsRemaining(in: block, at: date)) / duration))
    }

    private func progressLabel(for block: ScheduleBlock, at date: Date) -> String {
        "\(Int(progress(for: block, at: date) * 100))% elapsed"
    }

    private func countdown(for block: ScheduleBlock, at date: Date) -> String {
        let seconds = Int(schedule.secondsRemaining(in: block, at: date))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d remaining", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d remaining", minutes, remainingSeconds)
    }
}
