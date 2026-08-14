import SwiftUI

struct CodexCoachView: View {
    @EnvironmentObject private var model: AppModel
    @State private var question = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label("Coach", systemImage: "sparkles")
                    .font(.title3.weight(.semibold))
                Spacer()
                PetStatusBadge(
                    text: model.codex.isAvailable ? "Codex ready" : "Codex unavailable",
                    color: model.codex.isAvailable ? .green : .red,
                    systemImage: model.codex.isAvailable ? "checkmark" : "exclamationmark"
                )
            }

            Text("Ask for a concrete next move, explain what is stuck, or request more time. Schedule changes always wait for your approval.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                suggestion("Give me the next step", icon: "arrow.right.circle")
                suggestion("I need 20 more minutes", icon: "clock.badge.plus")
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(model.coachMessages.suffix(12)) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: model.coachMessages.count) { _, _ in
                    if let id = model.coachMessages.last?.id {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
            .frame(maxHeight: 220)

            if let proposal = model.pendingAdjustment {
                proposalCard(proposal)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Message TopBuddy…", text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit { send() }

                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .disabled(model.codexIsRunning || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send message")
            }

            if model.codexIsRunning {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text("TopBuddy is thinking…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .petSurface()
    }

    private func suggestion(_ title: String, icon: String) -> some View {
        Button {
            question = title
            send()
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func messageBubble(_ message: CoachMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 70) }
            if message.role == .pet {
                Image(systemName: "pawprint.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            Text(message.text)
                .font(.callout)
                .textSelection(.enabled)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(
                    message.role == .user ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            if message.role == .pet { Spacer(minLength: 70) }
        }
        .frame(maxWidth: .infinity)
    }

    private func proposalCard(_ proposal: ScheduleAdjustmentProposal) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(
                proposal.canApply ? "Review schedule change" : "Schedule conflict",
                systemImage: proposal.canApply ? "calendar.badge.clock" : "exclamationmark.triangle.fill"
            )
            .font(.callout.weight(.semibold))
            Text(proposal.summary)
                .font(.callout)
            HStack {
                if proposal.canApply {
                    Button("Apply locally") { model.applyPendingAdjustment() }
                        .buttonStyle(.borderedProminent)
                }
                Button("Keep current plan") { model.cancelPendingAdjustment() }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: PetDesign.compactRadius))
    }

    private func send() {
        let message = question
        question = ""
        model.sendCoachMessage(message)
    }
}
