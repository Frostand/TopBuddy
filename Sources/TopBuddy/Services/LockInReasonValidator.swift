import Foundation

enum LockInReasonError: LocalizedError, Equatable {
    case tooShort
    case tooVague
    case tooLong
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .tooShort:
            "Explain the task-specific reason in at least four words and 20 characters."
        case .tooVague:
            "Name what you need this for and what you will do before the exception ends."
        case .tooLong:
            "Keep the reason under 240 characters."
        case .invalidDuration:
            "Choose a 5, 10, 15, or 30 minute exception."
        }
    }
}

struct LockInReasonValidator {
    static let allowedDurations = [5, 10, 15, 30]

    static func validate(_ reason: String, durationMinutes: Int) throws -> String {
        guard allowedDurations.contains(durationMinutes) else {
            throw LockInReasonError.invalidDuration
        }
        let normalized = reason
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard normalized.count <= 240 else { throw LockInReasonError.tooLong }
        let lowered = normalized.lowercased()
        let vaguePhrases = [
            "because i want to",
            "i just want to",
            "just let me use it",
            "i need a break",
            "for fun",
            "i am bored"
        ]
        guard !vaguePhrases.contains(where: { lowered.contains($0) }) else {
            throw LockInReasonError.tooVague
        }
        let words = normalized.split(separator: " ")
        guard normalized.count >= 20, words.count >= 4 else { throw LockInReasonError.tooShort }
        return normalized
    }
}
