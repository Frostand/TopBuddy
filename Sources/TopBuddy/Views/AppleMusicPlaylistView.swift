import SwiftUI

struct AppleMusicPlaylistView: View {
    @ObservedObject var music: MusicHubStore
    @State private var search = ""
    @State private var selectedPlaylistID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your playlists", systemImage: "music.note.list")
                    .font(.headline)
                Spacer()
                TextField("Filter playlists", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }

            if filteredPlaylists.isEmpty {
                ContentUnavailableView(
                    "No playlists found",
                    systemImage: "music.note",
                    description: Text("Refresh after your Music library finishes loading.")
                )
                .frame(height: 180)
            } else {
                List(filteredPlaylists, selection: $selectedPlaylistID) { playlist in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playlist.name)
                                .font(.body.weight(.medium))
                            Text("\(playlist.trackCount) tracks · \(MusicTimeFormatter.duration(playlist.duration))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Play", systemImage: "play.fill") {
                            Task { await music.perform(.playPlaylist(playlist.id)) }
                        }
                        .buttonStyle(.borderless)
                    }
                    .tag(playlist.id)
                }
                .frame(minHeight: 220, idealHeight: 300)
            }
        }
        .petSurface()
    }

    private var filteredPlaylists: [MusicPlaylist] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return music.playlists }
        return music.playlists.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}
