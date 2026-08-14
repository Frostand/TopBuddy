import SwiftUI

struct ScheduleRowView: View {
    let block: ScheduleBlock
    let isCurrent: Bool
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : block.category.systemImage)
                .foregroundStyle(isCompleted ? Color.green : (isCurrent ? Color.accentColor : Color.secondary))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .lineLimit(1)
                    .strikethrough(isCompleted)
                Text(block.timeLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if isCurrent {
                Text("NOW")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(block.timeLabel)\(isCurrent ? ", current" : "")\(isCompleted ? ", completed" : "")")
    }
}
