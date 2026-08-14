import Foundation

enum CodexPetsClientError: LocalizedError, Equatable {
    case invalidURL
    case untrustedHost
    case badResponse(Int)
    case responseTooLarge
    case unsupportedPet

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Codex Pets returned an invalid address."
        case .untrustedHost:
            "The pet download did not stay on codex-pets.net."
        case let .badResponse(status):
            "Codex Pets returned HTTP \(status)."
        case .responseTooLarge:
            "The pet sprite is larger than the 25 MB safety limit."
        case .unsupportedPet:
            "This pet uses an unsupported sprite format."
        }
    }
}

struct CodexPetsClient: Sendable {
    static let productionBaseURL = URL(string: "https://codex-pets.net")!
    static let maximumSpriteBytes = 25_000_000

    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = Self.productionBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func gallery(query: String = "", page: Int = 1, pageSize: Int = 24) async throws -> CommunityPetGalleryResponse {
        let url = try galleryURL(query: query, page: page, pageSize: pageSize)
        return try await request(url, as: CommunityPetGalleryResponse.self)
    }

    func pet(id: String) async throws -> CommunityPet {
        guard PetLibraryStorage.isValidPetID(id) else { throw CodexPetsClientError.invalidURL }
        let url = baseURL.appending(path: "api/pets/\(id)")
        return try await request(url, as: CommunityPetDetailResponse.self).pet
    }

    func downloadSpritesheet(for pet: CommunityPet) async throws -> Data {
        guard pet.isVersionSupported else { throw CodexPetsClientError.unsupportedPet }
        let url = try trustedURL(from: pet.spritesheetUrl)
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30
        let (data, response) = try await session.data(for: request)
        try validate(response: response, dataCount: data.count)
        return data
    }

    func trustedURL(from value: String) throws -> URL {
        guard let url = URL(string: value, relativeTo: baseURL)?.absoluteURL else {
            throw CodexPetsClientError.invalidURL
        }
        guard url.scheme == "https", url.host == baseURL.host else {
            throw CodexPetsClientError.untrustedHost
        }
        return url
    }

    func galleryURL(query: String, page: Int, pageSize: Int) throws -> URL {
        guard var components = URLComponents(
            url: baseURL.appending(path: "api/pets"),
            resolvingAgainstBaseURL: false
        ) else {
            throw CodexPetsClientError.invalidURL
        }
        var items = [
            URLQueryItem(name: "page", value: String(max(1, page))),
            URLQueryItem(name: "pageSize", value: String(min(48, max(1, pageSize)))),
            URLQueryItem(name: "version", value: "2")
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "q", value: String(trimmed.prefix(80))))
        }
        components.queryItems = items
        guard let url = components.url else { throw CodexPetsClientError.invalidURL }
        return url
    }

    private func request<T: Decodable & Sendable>(_ url: URL, as type: T.Type) async throws -> T {
        guard url.scheme == "https", url.host == baseURL.host else {
            throw CodexPetsClientError.untrustedHost
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, dataCount: data.count)
        return try JSONDecoder().decode(type, from: data)
    }

    private func validate(response: URLResponse, dataCount: Int) throws {
        guard let response = response as? HTTPURLResponse else {
            throw CodexPetsClientError.badResponse(0)
        }
        guard response.url?.scheme == "https", response.url?.host == baseURL.host else {
            throw CodexPetsClientError.untrustedHost
        }
        guard (200..<300).contains(response.statusCode) else {
            throw CodexPetsClientError.badResponse(response.statusCode)
        }
        guard dataCount <= Self.maximumSpriteBytes else {
            throw CodexPetsClientError.responseTooLarge
        }
    }
}
