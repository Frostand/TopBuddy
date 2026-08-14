import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("General", systemImage: "gearshape") }

            permissionSettings
                .tabItem { Label("Permissions", systemImage: "lock.shield.fill") }

            PetSettingsPane(model: model, library: model.petLibrary)
                .tabItem { Label("Pet", systemImage: "pawprint.fill") }
        }
        .frame(width: 610, height: 470)
        .scenePadding()
    }

    private var generalSettings: some View {
        Form {
            Section("Notch and focus") {
                Toggle("Show TopBuddy in the notch", isOn: $model.floatingPetEnabled)
                Toggle("Automatically open block resources", isOn: $model.autoOpenResources)
                Toggle("Hide unrelated apps at block changes", isOn: $model.autoHideDistractions)
                Toggle("Show manual app-quit review tools", isOn: $model.quitReviewEnabled)
            }

            Section("Schedule boundary") {
                Picker("Hard stop", selection: $model.hardStopMinute) {
                    ForEach(Array(stride(from: 18 * 60, through: 24 * 60, by: 30)), id: \.self) { minute in
                        Text(timeLabel(minute)).tag(minute)
                    }
                }
                LabeledContent("Daily plan", value: model.schedule.activeDocument?.source ?? "Not imported")
                Button("Show local schedule folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.schedule.handoffURL])
                }
            }

            Section("Setup") {
                Button("Run setup again…") {
                    model.restartOnboarding()
                }
                Text("This preserves imported schedules, completion state, pets, and local workspace sessions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var permissionSettings: some View {
        Form {
            Section("Local integrations") {
                Toggle("Notion workspace", isOn: $model.notionWorkspaceEnabled)
                Toggle("Codex schedule coach", isOn: $model.codexCoachEnabled)
                Text("Notion keeps its sign-in inside this app's WebKit storage. Codex runs only after you send a message, in an ephemeral read-only sandbox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("macOS permissions") {
                LabeledContent("Apple Music", value: model.musicHub.controlsEnabled ? "Enabled" : "Not enabled")
                if model.musicHub.controlsEnabled {
                    Button("Disable Apple Music controls") {
                        model.musicHub.disableControls()
                    }
                } else {
                    Button("Enable Apple Music controls…") {
                        Task { await model.musicHub.enableControls() }
                    }
                }

                LabeledContent("Calendar", value: model.calendarAgenda.canRead ? "Read access enabled" : "Not enabled")
                if model.calendarAgenda.canRead {
                    Button("Disable Calendar inside TopBuddy") {
                        model.calendarAgenda.disable()
                    }
                } else {
                    Button("Enable Calendar read access…") {
                        Task { await model.calendarAgenda.requestAccess() }
                    }
                }
                Text("Disabling stops TopBuddy from using the integration. Revoke the underlying macOS grant separately in System Settings if desired.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Safety") {
                Label("Automatic focus mode can hide apps, but never quits them.", systemImage: "eye.slash")
                Label("Quit requests require a fresh selection and use normal app termination.", systemImage: "checkmark.shield")
                Label("TopBuddy includes no telemetry or analytics SDK.", systemImage: "waveform.path.ecg.rectangle")
            }
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
    }

    private func timeLabel(_ minute: Int) -> String {
        let normalized = minute % (24 * 60)
        let hour24 = normalized / 60
        let minutePart = normalized % 60
        let suffix = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minutePart, suffix)
    }
}

private struct PetSettingsPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: PetLibraryStore
    @State private var showsPetGallery = false

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                PetAvatarView(state: model.schedule.petState, library: library, size: 82)
                VStack(alignment: .leading, spacing: 4) {
                    Text(library.selectedName)
                        .font(.title3.weight(.semibold))
                    Text(library.selectedAttribution)
                        .foregroundStyle(.secondary)
                    Button("Choose or import a pet…", systemImage: "square.grid.2x2") {
                        showsPetGallery = true
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }

            Form {
                Toggle("Speak TopBuddy's replies aloud", isOn: $model.speakReplies)
                Text("Community pets download only when selected. Local imports never leave this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
        }
        .padding()
        .sheet(isPresented: $showsPetGallery) {
            PetGalleryView(library: library)
        }
    }
}
