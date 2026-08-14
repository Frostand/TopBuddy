import Foundation

struct CommunityPet: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let description: String
    let kind: String
    let tags: [String]
    let spriteVersionNumber: Int
    let ownerName: String
    let ownerHandle: String?
    let spritesheetUrl: String
    let posterUrl: String
    let downloadUrl: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case description
        case kind
        case tags
        case spriteVersionNumber
        case ownerName
        case ownerHandle
        case spritesheetUrl
        case posterUrl
        case downloadUrl
    }

    init(
        id: String,
        displayName: String,
        description: String,
        kind: String,
        tags: [String],
        spriteVersionNumber: Int,
        ownerName: String,
        ownerHandle: String?,
        spritesheetUrl: String,
        posterUrl: String,
        downloadUrl: String
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.kind = kind
        self.tags = tags
        self.spriteVersionNumber = spriteVersionNumber
        self.ownerName = ownerName
        self.ownerHandle = ownerHandle
        self.spritesheetUrl = spritesheetUrl
        self.posterUrl = posterUrl
        self.downloadUrl = downloadUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? "Community Codex pet"
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "creature"
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        spriteVersionNumber = try container.decodeIfPresent(Int.self, forKey: .spriteVersionNumber) ?? 1
        ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName) ?? "Community creator"
        ownerHandle = try container.decodeIfPresent(String.self, forKey: .ownerHandle)
        spritesheetUrl = try container.decode(String.self, forKey: .spritesheetUrl)
        posterUrl = try container.decode(String.self, forKey: .posterUrl)
        downloadUrl = try container.decode(String.self, forKey: .downloadUrl)
    }

    var attribution: String {
        "by \(ownerHandle ?? ownerName)"
    }

    var isVersionSupported: Bool {
        spriteVersionNumber == 1 || spriteVersionNumber == 2
    }
}

struct CommunityPetGalleryResponse: Decodable, Sendable {
    let page: Int
    let total: Int
    let totalPages: Int
    let pets: [CommunityPet]
}

struct CommunityPetDetailResponse: Decodable, Sendable {
    let pet: CommunityPet
}

struct InstalledCommunityPet: Codable, Identifiable, Equatable, Sendable {
    let pet: CommunityPet
    let installedAt: Date

    var id: String { pet.id }
}
