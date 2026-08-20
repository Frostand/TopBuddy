import SwiftUI

struct NotchBuddyPageView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var schedule: ScheduleStore
    @ObservedObject var presentation: NotchPresentationStore
    @State private var input = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            currentBlockCard
                .frame(maxWidth: .infinity)
            coachCard
                .frame(maxWidth: .infinity)
        }
        .onChange(of: inputFocused) { _, focused in
            if focused, !presentation.isPinned { presentation.togglePin() }
        }
    }

    private var currentBlockCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("RIGHT NOW", systemImage: "bolt.fill")
                .font(.caption2.weight(.black))
                .foregroundStyle(.cyan)

            if let block = schedule.currentBlock {
                Text(block.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(block.exactActions)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
                Text(block.finishTarget)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                HStack(spacing: 8) {
                    Button("Start", systemImage: "play.fill") { model.startCurrentBlock() }
                        .buttonStyle(.borderedProminent)
                    Button(
                        model.lockInModeEnabled ? "Unlock" : "Lock In",
                        systemImage: model.lockInModeEnabled ? "lock.open.fill" : "lock.fill"
                    ) { model.toggleLockInMode(for: block) }
                        .buttonStyle(.bordered)
                    Button(schedule.isCompleted(block) ? "Reopen" : "Done", systemImage: schedule.isCompleted(block) ? "arrow.uturn.backward" : "checkmark") {
                        model.toggleCurrentCompletion()
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.regular)

                if model.lockInModeEnabled {
                    Button("Open Lock In controls", systemImage: "slider.horizontal.3") {
                        model.showLockInWindow()
                    }
                    .buttonStyle(.link)
                    .controlSize(.regular)
                }
            } else {
                Text("No active block")
                    .font(.headline)
                Text("Open Agenda to see what comes next.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .notchCard()
    }

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("ASK YOUR BUDDY", systemImage: "bubble.left.and.bubble.right.fill")
                .font(.caption2.weight(.black))
                .foregroundStyle(.purple)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(model.coachMessages.suffix(4)) { message in
                            Text(message.text)
                                .font(.caption)
                                .lineLimit(3)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    message.role == .user ? Color.cyan.opacity(0.12) : Color.white.opacity(0.065),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
                                .id(message.id)
                        }
                    }
                }
                .onChange(of: model.coachMessages.count) { _, _ in
                    if let id = model.coachMessages.last?.id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            .frame(height: 102)

            HStack(spacing: 7) {
                TextField("Ask what to do or request more time…", text: $input)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .focused($inputFocused)
                    .onSubmit(send)
                Button(action: send) {
                    Image(systemName: model.codexIsRunning ? "ellipsis" : "arrow.up")
                }
                .buttonStyle(TopBuddyNotchIconButtonStyle(emphasized: true))
                .foregroundStyle(.white)
                .accessibilityLabel("Send message")
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.codexIsRunning)
            }
        }
        .notchCard()
    }

    private func send() {
        let message = input
        input = ""
        model.sendCoachMessage(message)
    }
}
private extension View {
    func notchCard() -> some View {
        padding(12)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            }
    }
}
