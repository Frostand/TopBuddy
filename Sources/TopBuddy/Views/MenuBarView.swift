import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var schedule: ScheduleStore
    @Environment(\.openWindow) private var openWindow
    @State private var showsPetGallery = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PetAvatarView(state: schedule.petState, library: model.petLibrary, size: 54)
                VStack(alignment: .leading) {
                    Text("TopBuddy · \(schedule.petState.label)")
                        .font(.headline)
                    Text(model.onboardingComplete ? (schedule.currentBlock?.title ?? "No active block") : "Setup required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if !model.onboardingComplete {
                Button("Finish TopBuddy setup", systemImage: "wand.and.stars") {
                    openMainWindow()
                }
                .buttonStyle(.borderedProminent)
            } else {
                if let block = schedule.currentBlock {
                    Text(block.timeLabel)
                        .font(.caption.monospacedDigit())
                    Text(block.finishTarget)
                        .font(.caption)
                        .lineLimit(3)

                    Button("Start focus", systemImage: "play.fill") {
                        model.startCurrentBlock()
                    }
                    Button(
                        model.lockInModeEnabled ? "End Lock In" : "Start Lock In",
                        systemImage: model.lockInModeEnabled ? "lock.open.fill" : "lock.fill"
                    ) {
                        model.toggleLockInMode(for: block)
                    }
                    if model.lockInModeEnabled {
                        Button("Show Lock In browser", systemImage: "safari") {
                            model.showLockInWindow()
                        }
                    }
                    Button(
                        schedule.isCompleted(block) ? "Reopen block" : "Mark block done",
                        systemImage: schedule.isCompleted(block) ? "arrow.uturn.backward" : "checkmark"
                    ) {
                        model.toggleCurrentCompletion()
                    }
                } else {
                    Text("Import today's schedule from the main window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Button("Open Workspace Hub", systemImage: "square.grid.2x2") {
                    openWindow(id: "workspace-hub")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Button("Open full TopBuddy", systemImage: "macwindow") {
                    openMainWindow()
                }
                Button(model.floatingPetEnabled ? "Hide TopBuddy notch" : "Show TopBuddy notch", systemImage: "pawprint") {
                    model.toggleFloatingPet()
                }
                Menu("Open notch page", systemImage: "rectangle.topthird.inset.filled") {
                    ForEach(TopBuddyNotchPage.allCases) { page in
                        Button(page.title, systemImage: page.systemImage) {
                            model.openNotch(page: page)
                        }
                    }
                }
                Button("Choose or import a pet", systemImage: "square.grid.2x2") {
                    showsPetGallery = true
                }
            }

            Divider()

            SettingsLink { Label("Settings…", systemImage: "gearshape") }
            Button("Quit TopBuddy", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 330)
        .sheet(isPresented: $showsPetGallery) {
            PetGalleryView(library: model.petLibrary)
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
