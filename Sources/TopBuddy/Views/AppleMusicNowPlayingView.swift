import SwiftUI

struct AppleMusicNowPlayingView: View {
    @ObservedObject var music: MusicHubStore
    @State private var scrubPosition = 0.0
    @State private var volume = 50.0
    @State private var isScrubbing = false
    @State private var isAdjustingVolume = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            trackSummary
            progressControls
            volumeControls
        }
        .petSurface()
        .onAppear { synchronizeLocalControls() }
        .onChange(of: music.snapshot.position) { _, value in
            if !isScrubbing { scrubPosition = value }
        }
        .onChange(of: music.snapshot.volume) { _, value in
            if !isAdjustingVolume { volume = Double(value) }
        }
    }

    private var trackSummary: some View {
        HStack(alignment: .top, spacing: 18) {
            MusicArtworkView(artworkData: music.artworkData, cornerRadius: 22)
                .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 6) {
                Text("NOW PLAYING")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(music.snapshot.trackName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Text(music.snapshot.artistName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(music.snapshot.albumName)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                transportControls
            }
            Spacer()
        }
    }

    private var transportControls: some View {
        HStack(spacing: 18) {
            Button {
                Task { await music.perform(.previousTrack) }
            } label: {
                Image(systemName: "backward.fill")
            }
            Button {
                Task { await music.perform(.playPause) }
            } label: {
                Image(systemName: music.snapshot.state.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            Button {
                Task { await music.perform(.nextTrack) }
            } label: {
                Image(systemName: "forward.fill")
            }

            Divider().frame(height: 24)

            Button {
                let enabled = !music.snapshot.shuffleEnabled
                music.setLocalShuffle(enabled)
                Task { await music.perform(.setShuffle(enabled)) }
            } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(music.snapshot.shuffleEnabled ? Color.accentColor : Color.secondary)
            }
            .help("Shuffle")

            Text("Repeat: \(music.snapshot.repeatMode.capitalized)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
    }

    private var progressControls: some View {
        VStack(spacing: 5) {
            Slider(
                value: $scrubPosition,
                in: 0.0...max(1.0, music.snapshot.duration),
                onEditingChanged: scrubChanged
            )
            HStack {
                Text(MusicTimeFormatter.clock(scrubPosition))
                Spacer()
                Text("−\(MusicTimeFormatter.clock(max(0, music.snapshot.duration - scrubPosition)))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var volumeControls: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
            Slider(
                value: $volume,
                in: 0.0...100.0,
                onEditingChanged: volumeChanged
            )
            .frame(maxWidth: 260)
            Image(systemName: "speaker.wave.3.fill")
            Text("\(Int(volume.rounded()))%")
                .font(.caption.monospacedDigit())
                .frame(width: 38, alignment: .trailing)
            Spacer()
            Text(music.snapshot.state.rawValue.capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(music.snapshot.state.isPlaying ? Color.green : Color.secondary)
        }
        .foregroundStyle(.secondary)
    }

    private func scrubChanged(_ editing: Bool) {
        isScrubbing = editing
        if !editing {
            music.setLocalPosition(scrubPosition)
            Task { await music.perform(.seek(scrubPosition)) }
        }
    }

    private func volumeChanged(_ editing: Bool) {
        isAdjustingVolume = editing
        if !editing {
            let value = Int(volume.rounded())
            music.setLocalVolume(value)
            Task { await music.perform(.setVolume(value)) }
        }
    }

    private func synchronizeLocalControls() {
        scrubPosition = music.snapshot.position
        volume = Double(music.snapshot.volume)
    }
}

enum MusicTimeFormatter {
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = max(0, Int(seconds / 60))
        if minutes >= 60 { return "\(minutes / 60) hr \(minutes % 60) min" }
        return "\(minutes) min"
    }
}
