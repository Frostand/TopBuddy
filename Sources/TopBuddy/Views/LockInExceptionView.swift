import SwiftUI

struct LockInExceptionView: View {
    @ObservedObject var lockIn: LockInStore
    let onGranted: (LockInAttempt) -> Void

    @State private var reason = ""
    @State private var durationMinutes = 10
    @State private var errorMessage = ""

    var body: some View {
        if let attempt = lockIn.pendingAttempt {
            VStack(alignment: .leading, spacing: 10) {
                Label("Blocked \(attempt.label)", systemImage: "hand.raised.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Explain why this is necessary for the current block and what you will finish before access expires.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("Example: I need this documentation to verify the API call in today’s program.", text: $reason, axis: .vertical)
                    .lineLimit(2...4)

                HStack {
                    Picker("Exception", selection: $durationMinutes) {
                        ForEach(LockInReasonValidator.allowedDurations, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .frame(width: 170)

                    Spacer()
                    Button("Keep blocked") {
                        lockIn.cancelPending()
                        reset()
                    }
                    Button("Allow temporarily") {
                        grant()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("Reasons and exceptions stay in memory for this Lock In session. TopBuddy checks specificity, not whether a claim is true.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(13)
            .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
            .onChange(of: attempt.id) { _, _ in reset() }
        }
    }

    private func grant() {
        do {
            let attempt = try lockIn.grantPending(
                reason: reason,
                durationMinutes: durationMinutes
            )
            onGranted(attempt)
            reset()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reset() {
        reason = ""
        durationMinutes = 10
        errorMessage = ""
    }
}
