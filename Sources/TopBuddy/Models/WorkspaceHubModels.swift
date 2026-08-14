import Foundation

enum WorkspaceHubSection: String, CaseIterable, Identifiable {
    case overview
    case notion
    case appleMusic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .notion: "Notion"
        case .appleMusic: "Apple Music"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .notion: "doc.text"
        case .appleMusic: "music.note"
        }
    }
}

enum MusicPlaybackState: String, Codable, Sendable {
    case playing
    case paused
    case stopped
    case fastForwarding = "fast forwarding"
    case rewinding
    case unknown

    init(rawValueOrUnknown value: String) {
        self = MusicPlaybackState(rawValue: value.lowercased()) ?? .unknown
    }

    var isPlaying: Bool { self == .playing }
}

struct MusicPlaybackSnapshot: Equatable, Sendable {
    let isMusicRunning: Bool
    var state: MusicPlaybackState
    var trackName: String
    var artistName: String
    var albumName: String
    var duration: Double
    var position: Double
    var volume: Int
    var shuffleEnabled: Bool
    var repeatMode: String

    var hasTrack: Bool {
        isMusicRunning && !trackName.isEmpty && trackName != "Nothing playing"
    }

    var shouldShowCompactNowPlaying: Bool {
        hasTrack && state.isPlaying
    }

    var artworkIdentity: String? {
        guard hasTrack else { return nil }
        return [trackName, artistName, albumName, String(format: "%.3f", duration)]
            .joined(separator: "\u{001F}")
    }

    static let notRunning = MusicPlaybackSnapshot(
        isMusicRunning: false,
        state: .stopped,
        trackName: "Music is not open",
        artistName: "",
        albumName: "",
        duration: 0,
        position: 0,
        volume: 50,
        shuffleEnabled: false,
        repeatMode: "off"
    )

    init(serialized value: String) throws {
        let fields = value.split(separator: "\u{001E}", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 9,
              let duration = Double(fields[4]),
              let position = Double(fields[5]),
              let volume = Int(fields[6]) else {
            throw MusicAutomationError.invalidResponse
        }

        isMusicRunning = true
        state = MusicPlaybackState(rawValueOrUnknown: fields[0])
        trackName = fields[1].isEmpty ? "Nothing playing" : fields[1]
        artistName = fields[2]
        albumName = fields[3]
        self.duration = max(0, duration)
        self.position = max(0, position)
        self.volume = min(100, max(0, volume))
        shuffleEnabled = fields[7].lowercased() == "true"
        repeatMode = fields[8].lowercased()
    }

    init(
        isMusicRunning: Bool,
        state: MusicPlaybackState,
        trackName: String,
        artistName: String,
        albumName: String,
        duration: Double,
        position: Double,
        volume: Int,
        shuffleEnabled: Bool,
        repeatMode: String
    ) {
        self.isMusicRunning = isMusicRunning
        self.state = state
        self.trackName = trackName
        self.artistName = artistName
        self.albumName = albumName
        self.duration = duration
        self.position = position
        self.volume = volume
        self.shuffleEnabled = shuffleEnabled
        self.repeatMode = repeatMode
    }
}

struct MusicPlaylist: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let trackCount: Int
    let duration: Double

    init(serializedRow row: String) throws {
        let fields = row.split(separator: "\u{001E}", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 4,
              Self.isValidPersistentID(fields[0]),
              let trackCount = Int(fields[2]),
              let duration = Double(fields[3]) else {
            throw MusicAutomationError.invalidResponse
        }

        id = fields[0].uppercased()
        name = fields[1].isEmpty ? "Untitled playlist" : fields[1]
        self.trackCount = max(0, trackCount)
        self.duration = max(0, duration)
    }

    static func parseList(_ value: String) -> [MusicPlaylist] {
        value
            .split(separator: "\u{001F}", omittingEmptySubsequences: true)
            .compactMap { try? MusicPlaylist(serializedRow: String($0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func isValidPersistentID(_ value: String) -> Bool {
        (8...32).contains(value.count) && value.allSatisfy(\.isHexDigit)
    }
}
