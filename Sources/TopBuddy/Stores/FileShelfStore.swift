import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class FileShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    @Published var errorMessage: String?

    private let storageURL: URL
    private let fileManager: FileManager
    private let maximumItems = 40

    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory = directoryURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("TopBuddy", isDirectory: true)
        storageURL = directory.appendingPathComponent("file-shelf.json")
        load()
    }

    @discardableResult
    func add(urls: [URL]) -> Int {
        let fileURLs = urls
            .filter(\.isFileURL)
            .map(\.standardizedFileURL)
        guard !fileURLs.isEmpty else { return 0 }

        var existingPaths = Set(items.map(\.path))
        var added = 0
        for url in fileURLs where !existingPaths.contains(url.path) {
            items.insert(ShelfItem(url: url), at: 0)
            existingPaths.insert(url.path)
            added += 1
        }
        if items.count > maximumItems {
            items.removeLast(items.count - maximumItems)
        }
        persist()
        return added
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func removeMissingReferences() {
        items.removeAll { !fileManager.fileExists(atPath: $0.path) }
        persist()
    }

    func open(_ item: ShelfItem) {
        guard fileManager.fileExists(atPath: item.path) else {
            errorMessage = "That file moved or was deleted. Remove its shelf reference or locate it again."
            return
        }
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func share(_ item: ShelfItem, from view: NSView?) {
        guard let view else {
            reveal(item)
            return
        }
        NSSharingServicePicker(items: [item.url]).show(
            relativeTo: view.bounds,
            of: view,
            preferredEdge: .minY
        )
    }

    func receive(_ providers: [NSItemProvider]) -> Bool {
        let eligible = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !eligible.isEmpty else { return false }
        for provider in eligible {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                let url: URL?
                if let value = item as? URL {
                    url = value
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let string = item as? String {
                    url = URL(string: string)
                } else {
                    url = nil
                }
                Task { @MainActor in
                    if let error {
                        self?.errorMessage = error.localizedDescription
                    } else if let url {
                        _ = self?.add(urls: [url])
                    }
                }
            }
        }
        return true
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else { return }
        items = Array(decoded.prefix(maximumItems))
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageURL.path)
            errorMessage = nil
        } catch {
            errorMessage = "TopBuddy could not save the shelf: \(error.localizedDescription)"
        }
    }
}
