import Foundation
import ImageIO

enum PetLibraryStorageError: LocalizedError, Equatable {
    case invalidIdentifier
    case invalidWebP
    case invalidAtlas(expected: String, actual: String)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            "The pet identifier is not safe to store locally."
        case .invalidWebP:
            "The downloaded file is not a valid WebP sprite sheet."
        case let .invalidAtlas(expected, actual):
            "The sprite atlas is \(actual); expected \(expected)."
        case .invalidImage:
            "The selected file is not a readable image."
        }
    }
}

enum ImportedPetAssetKind: Equatable, Sendable {
    case animated(version: Int)
    case staticImage
}

struct PetLibraryStorage {
    let rootURL: URL
    private let fileManager: FileManager

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.rootURL = support
                .appending(path: "TopBuddy", directoryHint: .isDirectory)
                .appending(path: "Pets", directoryHint: .isDirectory)
        }
    }

    func installedPets() throws -> [InstalledCommunityPet] {
        guard fileManager.fileExists(atPath: rootURL.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .compactMap { directory -> InstalledCommunityPet? in
            guard Self.isValidPetID(directory.lastPathComponent) else { return nil }
            let metadataURL = directory.appending(path: "source.json")
            let spritesheetURL = directory.appending(path: "spritesheet.webp")
            guard fileManager.fileExists(atPath: spritesheetURL.path) else { return nil }
            let data = try Data(contentsOf: metadataURL)
            return try decoder.decode(InstalledCommunityPet.self, from: data)
        }
        .sorted { $0.installedAt > $1.installedAt }
    }

    func install(_ pet: CommunityPet, spritesheet: Data) throws -> InstalledCommunityPet {
        guard Self.isValidPetID(pet.id) else { throw PetLibraryStorageError.invalidIdentifier }
        try Self.validateSpritesheet(spritesheet, version: pet.spriteVersionNumber)

        return try persist(pet, asset: spritesheet)
    }

    func installImported(_ pet: CommunityPet, asset: Data, kind: ImportedPetAssetKind) throws -> InstalledCommunityPet {
        guard Self.isValidPetID(pet.id) else { throw PetLibraryStorageError.invalidIdentifier }
        switch kind {
        case let .animated(version):
            try Self.validateSpritesheet(asset, version: version)
        case .staticImage:
            try Self.validateStaticImage(asset)
        }
        return try persist(pet, asset: asset)
    }

    static func inspectImportedAsset(_ data: Data) throws -> ImportedPetAssetKind {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw PetLibraryStorageError.invalidImage
        }
        if width == 1_536, height == 1_872 { return .animated(version: 1) }
        if width == 1_536, height == 2_288 { return .animated(version: 2) }
        return .staticImage
    }

    static func validateStaticImage(_ data: Data) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            throw PetLibraryStorageError.invalidImage
        }
    }

    private func persist(_ pet: CommunityPet, asset: Data) throws -> InstalledCommunityPet {

        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: rootURL.path)

        let directory = directoryURL(for: pet.id)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let installed = InstalledCommunityPet(pet: pet, installedAt: Date())
        let spritesheetURL = spritesheetURL(for: pet.id)
        let metadataURL = directory.appending(path: "source.json")
        try asset.write(to: spritesheetURL, options: .atomic)
        try encoder.encode(installed).write(to: metadataURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: spritesheetURL.path)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: metadataURL.path)
        return installed
    }

    func spritesheetURL(for id: String) -> URL {
        directoryURL(for: id).appending(path: "spritesheet.webp")
    }

    static func isValidPetID(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 80, id.first?.isLetter == true || id.first?.isNumber == true else {
            return false
        }
        return id.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }
    }

    static func validateSpritesheet(_ data: Data, version: Int) throws {
        guard data.count >= 12,
              String(data: data.prefix(4), encoding: .ascii) == "RIFF",
              String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WEBP",
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw PetLibraryStorageError.invalidWebP
        }

        let expectedHeight = version == 2 ? 2_288 : 1_872
        guard width == 1_536, height == expectedHeight else {
            throw PetLibraryStorageError.invalidAtlas(
                expected: "1536x\(expectedHeight)",
                actual: "\(width)x\(height)"
            )
        }
    }

    private func directoryURL(for id: String) -> URL {
        rootURL.appending(path: id, directoryHint: .isDirectory)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
