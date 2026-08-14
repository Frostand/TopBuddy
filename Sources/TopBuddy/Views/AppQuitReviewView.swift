import SwiftUI

struct AppQuitReviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showsConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Review running apps")
                        .font(.title2.weight(.bold))
                    Text("Select apps that may receive a normal quit request.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") {
                    model.refreshRunningApps()
                }
            }

            Text("TopBuddy never force-quits. An app with unsaved work remains responsible for showing its normal save prompt.")
                .font(.callout)
                .padding(10)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            List(model.workspace.runningApps) { app in
                Toggle(
                    isOn: Binding(
                        get: { model.selectedQuitBundleIDs.contains(app.bundleIdentifier) },
                        set: { selected in
                            if selected {
                                model.selectedQuitBundleIDs.insert(app.bundleIdentifier)
                            } else {
                                model.selectedQuitBundleIDs.remove(app.bundleIdentifier)
                            }
                        }
                    )
                ) {
                    VStack(alignment: .leading) {
                        Text(app.name)
                        Text(app.bundleIdentifier)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minHeight: 260)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Request quit…", role: .destructive) {
                    showsConfirmation = true
                }
                .disabled(model.selectedQuitBundleIDs.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
        .onAppear { model.refreshRunningApps() }
        .confirmationDialog(
            "Ask the selected apps to quit?",
            isPresented: $showsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Request normal quit", role: .destructive) {
                model.requestQuitSelectedApps()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No app will be force-quit. Review any save prompts before continuing.")
        }
    }
}
