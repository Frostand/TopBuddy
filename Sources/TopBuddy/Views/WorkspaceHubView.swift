import SwiftUI

struct WorkspaceHubView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var notionBrowser = NotionBrowserStore()
    @SceneStorage("topbuddy.workspace-hub-section") private var selectionRaw = WorkspaceHubSection.overview.rawValue

    private var selection: Binding<WorkspaceHubSection?> {
        Binding(
            get: { WorkspaceHubSection(rawValue: selectionRaw) ?? .overview },
            set: { selectionRaw = ($0 ?? .overview).rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(WorkspaceHubSection.allCases, selection: selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("Workspace Hub")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 250)
        } detail: {
            switch WorkspaceHubSection(rawValue: selectionRaw) ?? .overview {
            case .overview:
                overview
            case .notion:
                if model.notionWorkspaceEnabled {
                    NotionWorkspaceView(browser: notionBrowser)
                } else {
                    disabledNotion
                }
            case .appleMusic:
                AppleMusicHubView(music: model.musicHub)
            }
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    PetAvatarView(state: model.schedule.petState, library: model.petLibrary, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optional tools, one window")
                            .font(.largeTitle.weight(.semibold))
                        Text("Use only the workspace features you explicitly enable.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    hubCard(
                        title: "Notion",
                        subtitle: model.notionWorkspaceEnabled
                            ? "Browse your workspace in a persistent local WebKit session."
                            : "Disabled. Enable it here or in Settings when you want it.",
                        systemImage: "doc.text",
                        color: .blue,
                        action: { selectionRaw = WorkspaceHubSection.notion.rawValue }
                    )
                    hubCard(
                        title: "Apple Music",
                        subtitle: model.musicHub.controlsEnabled
                            ? "Control playback, volume, seeking, shuffle, and playlists."
                            : "Permission not requested. Enable it from the Music page if desired.",
                        systemImage: "music.note",
                        color: .pink,
                        action: { selectionRaw = WorkspaceHubSection.appleMusic.rawValue }
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Local privacy boundary", systemImage: "lock.shield.fill")
                        .font(.headline)
                    Text("Notion sign-in remains in local WebKit storage. Apple Music access uses the Mac's Automation permission and fixed commands. TopBuddy does not copy passwords, cookies, tokens, or Music-library contents into schedule or coach files.")
                        .foregroundStyle(.secondary)
                }
                .petSurface()
            }
            .frame(maxWidth: 850)
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Workspace Hub")
    }

    private var disabledNotion: some View {
        ContentUnavailableView {
            Label("Notion workspace is off", systemImage: "doc.text")
        } description: {
            Text("Enabling it creates a local WebKit session. TopBuddy never copies its cookies or sign-in data elsewhere.")
        } actions: {
            Button("Enable Notion workspace") {
                model.notionWorkspaceEnabled = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func hubCard(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(title).font(.title2.weight(.semibold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Label("Open", systemImage: "arrow.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .petSurface()
        }
        .buttonStyle(.plain)
    }
}
