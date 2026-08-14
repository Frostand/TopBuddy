import SwiftUI

struct NotchMusicPageView: View {
    @ObservedObject var music: MusicHubStore
    @State private var position = 0.0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 14) {
            if music.controlsEnabled {
                if music.snapshot.hasTrack {
                    nowPlaying
                } else {
                    emptyPlayer
                }
            } else {
                enableControls
            }
        }
        .task {
            await music.prepare()
        }
        .onChange(of: music.snapshot.position) { _, value in
            if !isScrubbing { position = value }
        }
        .onAppear { position = music.snapshot.position }
    }

    private var nowPlaying: some View {
        HStack(spacing: 22) {
            MusicArtworkView(artworkData: music.artworkData, cornerRadius: 20)
                .frame(width: 132, height: 132)
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(music.snapshot.trackName)
                            .font(.title2.weight(.bold))
                            .lineLimit(1)
                        Text(music.snapshot.artistName.isEmpty ? "Apple Music" : music.snapshot.artistName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.indigo)
                            .lineLimit(1)
                    }
                    Spacer()
                    MusicActivityBars(
                        isPlaying: music.snapshot.state.isPlaying,
                        color: .indigo,
                        maximumHeight: 18
                    )
                    .frame(width: 27)
                }

                Slider(value: $position, in: 0...max(1, music.snapshot.duration)) { editing in
                    isScrubbing = editing
                    if !editing {
                        music.setLocalPosition(position)
                        Task { await music.perform(.seek(position)) }
                    }
                }
                .tint(.white)

                HStack {
                    Text(MusicTimeFormatter.clock(position))
                    Spacer()
                    Text(MusicTimeFormatter.clock(music.snapshot.duration))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 28) {
                    Spacer()
                    Button { Task { await music.perform(.previousTrack) } } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                    }
                    Button { Task { await music.perform(.playPause) } } label: {
                        Image(systemName: music.snapshot.state.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .frame(width: 34, height: 34)
                    }
                    Button { Task { await music.perform(.nextTrack) } } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                    }
                    Spacer()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.indigo.opacity(0.18), .white.opacity(0.055), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(alignment: .bottomTrailing) {
            Button("Open Music", systemImage: "arrow.up.forward.app", action: music.openMusic)
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .padding(14)
        }
    }

    private var emptyPlayer: some View {
        VStack(spacing: 12) {
            MusicArtworkView(artworkData: nil, cornerRadius: 18)
                .frame(width: 86, height: 86)
            Text(music.isMusicRunning ? "Choose a song in Apple Music" : "Apple Music is not open")
                .font(.headline)
            Text("Start playback and TopBuddy will place the album art in the compact notch automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Music", systemImage: "music.note", action: music.openMusic)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var enableControls: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 38))
                .foregroundStyle(.pink)
            Text("Apple Music in the notch")
                .font(.headline)
            Text("Enable explicit playback access to use play, pause, seek, shuffle, volume, and playlists. TopBuddy never receives your Apple ID password.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 430)
            Button("Enable Apple Music controls") { Task { await music.enableControls() } }
                .buttonStyle(.borderedProminent)
                .disabled(music.isBusy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
