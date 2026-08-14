import AppKit
import SwiftUI

struct ScheduleImportView: View {
    @EnvironmentObject private var schedule: ScheduleStore
    @Environment(\.dismiss) private var dismiss
    @State private var pastedText = ""
    @State private var preview: DailyScheduleDocument?
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(20)

            Divider()

            HSplitView {
                editor
                    .frame(minWidth: 430)
                previewPane
                    .frame(minWidth: 330)
            }

            if !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
            }

            Divider()

            footer
                .padding(14)
        }
        .frame(minWidth: 840, minHeight: 590)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("Import today's plan")
                    .font(.title2.weight(.semibold))
                Text("TopBuddy checks every time range, duplicate ID, and overlap before anything changes.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Paste from Clipboard", systemImage: "doc.on.clipboard") { paste() }
                .controlSize(.large)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PetSectionLabel(title: "Schedule table", systemImage: "text.alignleft")
                Spacer()
                Text("Markdown or TSV")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $pastedText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1)))

            Text("Four columns: Time, Task, Exact actions, Finish target. Include AM/PM on at least one side of every range.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PetSectionLabel(title: "Preview", systemImage: "eye")
                Spacer()
                if let preview {
                    PetStatusBadge(text: "\(preview.blocks.count) blocks", color: .blue)
                }
            }

            if let preview {
                List(preview.blocks) { block in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(block.timeLabel)
                                .font(.caption.monospacedDigit().weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: block.category.systemImage)
                                .foregroundStyle(.secondary)
                        }
                        Text(block.title)
                            .font(.callout.weight(.semibold))
                        if !block.resources.isEmpty {
                            Text("Opens \(block.resources.map(\.label).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            } else {
                ContentUnavailableView(
                    "Nothing to preview",
                    systemImage: "tablecells",
                    description: Text("Paste a schedule, then choose Validate.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(18)
    }

    private var footer: some View {
        HStack {
            Label("Connected services remain read-only", systemImage: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(preview == nil ? "Validate schedule" : "Apply today") {
                preview == nil ? validate() : apply()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func paste() {
        pastedText = NSPasteboard.general.string(forType: .string) ?? ""
        preview = nil
        errorMessage = ""
    }

    private func validate() {
        do {
            preview = try ScheduleImportParser().parse(pastedText, for: schedule.now)
            errorMessage = ""
        } catch {
            preview = nil
            errorMessage = error.localizedDescription
        }
    }

    private func apply() {
        guard let preview else { return }
        do {
            try schedule.importToday(preview)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
