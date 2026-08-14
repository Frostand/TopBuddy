import AppKit
import Foundation

@MainActor
final class PetLibraryStore: ObservableObject {
    @Published private(set) var catalog: [CommunityPet] = []
    @Published private(set) var installedPets: [InstalledCommunityPet] = []
    @Published private(set) var selectedPet: InstalledCommunityPet?
    @Published private(set) var selectedSpritesheet: NSImage?
    @Published private(set) var isLoading = false
    @Published private(set) var installingPetID: String?
    @Published var errorMessage: String?

    private static let selectedPetKey = "topbuddy.selected-community-pet"
    private let client: CodexPetsClient
    private let storage: PetLibraryStorage
    private let defaults: UserDefaults
    private var hasPrepared = false

    init(
        client: CodexPetsClient = CodexPetsClient(),
        storage: PetLibraryStorage = PetLibraryStorage(),
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.storage = storage
        self.defaults = defaults
        loadInstalledPets()
    }

    var selectedName: String {
        selectedPet?.pet.displayName ?? "Default paw"
    }

    var selectedAttribution: String {
        selectedPet?.pet.attribution ?? "built into macOS"
    }

    var installedIDs: Set<String> {
        Set(installedPets.map(\.id))
    }

    func prepare() async {
        guard !hasPrepared else { return }
        hasPrepared = true
    }

    func refreshCatalog(query: String = "") async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await client.gallery(query: query)
            catalog = response.pets.filter(\.isVersionSupported)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load Codex Pets: \(error.localizedDescription)"
        }
    }

    func use(_ pet: CommunityPet) async {
        if let installed = installedPets.first(where: { $0.id == pet.id }) {
            select(installed)
            return
        }

        do {
            try await installAndSelect(pet)
            errorMessage = nil
        } catch {
            errorMessage = "Could not install \(pet.displayName): \(error.localizedDescription)"
        }
    }

    func select(_ pet: InstalledCommunityPet) {
        selectedPet = pet
        selectedSpritesheet = NSImage(contentsOf: storage.spritesheetURL(for: pet.id))
        defaults.set(pet.id, forKey: Self.selectedPetKey)
    }

    func importPet(from url: URL) {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer { if hasScopedAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard data.count <= CodexPetsClient.maximumSpriteBytes else {
                throw CodexPetsClientError.responseTooLarge
            }
            let assetKind = try PetLibraryStorage.inspectImportedAsset(data)
            let displayName = url.deletingPathExtension().lastPathComponent.isEmpty
                ? "Imported pet"
                : url.deletingPathExtension().lastPathComponent
            let baseSlug = displayName.lowercased()
                .unicodeScalars
                .map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-" }
            let compactSlug = String(baseSlug)
                .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            let suffix = UUID().uuidString.lowercased().prefix(8)
            let identifier = "local-\(String(compactSlug.prefix(48)))-\(suffix)"
            let version: Int
            let kind: String
            switch assetKind {
            case let .animated(assetVersion):
                version = assetVersion
                kind = "local-animated"
            case .staticImage:
                version = 1
                kind = "local-static"
            }
            let pet = CommunityPet(
                id: identifier,
                displayName: displayName,
                description: "Imported from this Mac",
                kind: kind,
                tags: ["local"],
                spriteVersionNumber: version,
                ownerName: "Local import",
                ownerHandle: nil,
                spritesheetUrl: "local://\(identifier)",
                posterUrl: "",
                downloadUrl: ""
            )
            let installed = try storage.installImported(pet, asset: data, kind: assetKind)
            installedPets.removeAll { $0.id == installed.id }
            installedPets.insert(installed, at: 0)
            select(installed)
            errorMessage = nil
        } catch {
            errorMessage = "Could not import this pet: \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func installAndSelect(_ pet: CommunityPet) async throws {
        guard installingPetID == nil else { return }
        installingPetID = pet.id
        defer { installingPetID = nil }

        let data = try await client.downloadSpritesheet(for: pet)
        let installed = try storage.install(pet, spritesheet: data)
        installedPets.removeAll { $0.id == installed.id }
        installedPets.insert(installed, at: 0)
        select(installed)
    }

    private func loadInstalledPets() {
        do {
            installedPets = try storage.installedPets()
            let selectedID = defaults.string(forKey: Self.selectedPetKey)
            if let selectedID, let selected = installedPets.first(where: { $0.id == selectedID }) {
                select(selected)
            } else if let first = installedPets.first {
                select(first)
            }
        } catch {
            errorMessage = "Could not read the local pet library: \(error.localizedDescription)"
        }
    }
}
