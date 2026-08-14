import SwiftUI

struct AppleMusicHubView: View {
    @ObservedObject var music: MusicHubStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MusicHubHeader(music: music)

                if let error = music.errorMessage {
                    MusicHubErrorBanner(music: music, message: error)
                }

                if music.controlsEnabled {
                    AppleMusicNowPlayingView(music: music)
                    AppleMusicPlaylistView(music: music)
                } else {
                    MusicControlsEnableView(music: music)
                }
            }
            .frame(maxWidth: 900)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Apple Music")
        .task {
            await music.prepare()
        }
    }
}

private struct MusicHubHeader: View {
    @ObservedObject var music: MusicHubStore

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "music.note")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(
                        colors: [.pink, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Music")
                    .font(.title2.weight(.semibold))
                Text(music.controlsEnabled ? "Playback and your playlists, without leaving TopBuddy" : "Connect to the installed Music app when you are ready")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open Music", systemImage: "arrow.up.forward.app", action: music.openMusic)
            Button {
                Task { await music.refreshAll() }
            } label: {
                if music.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .disabled(!music.controlsEnabled || music.isBusy)
        }
    }
}

private struct MusicControlsEnableView: View {
    @ObservedObject var music: MusicHubStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Enable Music controls", systemImage: "lock.shield.fill")
                .font(.headline)
            Text("macOS will ask whether TopBuddy may control Music. This grants playback and playlist access only; no Apple ID password, token, or Music library is copied into TopBuddy.")
                .foregroundStyle(.secondary)
            HStack {
                Button("Enable Apple Music controls") {
                    Task { await music.enableControls() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(music.isBusy)
                if music.isBusy { ProgressView().controlSize(.small) }
                Spacer()
                Text(music.isMusicRunning ? "Music is open" : "Music will open in the background")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .petSurface()
    }
}

private struct MusicHubErrorBanner: View {
    @ObservedObject var music: MusicHubStore
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
            Spacer()
            if message.localizedCaseInsensitiveContains("permission") {
                Button("Open Automation Settings", action: music.openAutomationSettings)
            }
            Button("Dismiss") { music.errorMessage = nil }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
