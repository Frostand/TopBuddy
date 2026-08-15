import Foundation

struct StudyMaterial: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        case book
        case file
        case physical
        case note

        var systemImage: String {
            switch self {
            case .book: "book.closed.fill"
            case .file: "doc.fill"
            case .physical: "tray.full.fill"
            case .note: "note.text"
            }
        }
    }

    let kind: Kind
    let label: String
    let detail: String

    var id: String { "\(kind.rawValue):\(label):\(detail)" }

    var isValid: Bool {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedLabel.isEmpty
            && !trimmedDetail.isEmpty
            && trimmedLabel.count <= 120
            && trimmedDetail.count <= 500
            && !trimmedLabel.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            && !trimmedDetail.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }
}
