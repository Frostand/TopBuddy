import Foundation

enum CodexBridgeError: LocalizedError {
    case executableNotFound
    case failed(exitCode: Int32, diagnostic: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "Codex CLI was not found. Install Codex or set a supported executable path."
        case let .failed(exitCode, diagnostic):
            "Codex exited with status \(exitCode). \(diagnostic)"
        case .emptyResponse:
            "Codex finished without returning a coaching response."
        }
    }
}

struct CodexBridge: Sendable {
    let executableURL: URL?

    init(executableURL: URL? = CodexBridge.resolveExecutable()) {
        self.executableURL = executableURL
    }

    var isAvailable: Bool { executableURL != nil }

    func ask(question: String, scheduleContext: String) async throws -> String {
        guard let executableURL else { throw CodexBridgeError.executableNotFound }
        let safeQuestion = String(question.prefix(4_000))
        let safeContext = String(scheduleContext.prefix(6_000))

        return try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let identifier = UUID().uuidString
            let responseURL = fileManager.temporaryDirectory
                .appendingPathComponent("topbuddy-response-\(identifier).txt")
            let diagnosticURL = fileManager.temporaryDirectory
                .appendingPathComponent("topbuddy-diagnostic-\(identifier).txt")
            let workingDirectoryURL = fileManager.temporaryDirectory
                .appendingPathComponent("topbuddy-codex-\(identifier)", isDirectory: true)
            try fileManager.createDirectory(
                at: workingDirectoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            fileManager.createFile(atPath: diagnosticURL.path, contents: nil)
            defer {
                try? fileManager.removeItem(at: responseURL)
                try? fileManager.removeItem(at: diagnosticURL)
                try? fileManager.removeItem(at: workingDirectoryURL)
            }

            let prompt = """
            Act as a concise schedule coach. Do not modify files, apps, websites, or external services. Do not claim an action is complete without evidence. Use the exact current block and finish target below, then answer the question with an immediately executable next step.

            SCHEDULE CONTEXT
            \(safeContext)

            USER QUESTION
            \(safeQuestion)
            """

            let process = Process()
            process.executableURL = executableURL
            process.currentDirectoryURL = workingDirectoryURL
            process.arguments = [
                "exec",
                "--ephemeral",
                "--sandbox", "read-only",
                "--skip-git-repo-check",
                "--output-last-message", responseURL.path,
                prompt
            ]

            let diagnosticHandle = try FileHandle(forWritingTo: diagnosticURL)
            process.standardOutput = diagnosticHandle
            process.standardError = diagnosticHandle
            try process.run()
            process.waitUntilExit()
            try diagnosticHandle.close()

            let diagnostic = (try? String(contentsOf: diagnosticURL, encoding: .utf8)) ?? ""
            guard process.terminationStatus == 0 else {
                throw CodexBridgeError.failed(
                    exitCode: process.terminationStatus,
                    diagnostic: String(diagnostic.suffix(1_000))
                )
            }
            let response = (try? String(contentsOf: responseURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !response.isEmpty else { throw CodexBridgeError.emptyResponse }
            return String(response.prefix(20_000))
        }.value
    }

    static func resolveExecutable(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL? {
        var candidates: [String] = []
        if let override = environment["TOPBUDDY_CODEX_PATH"], !override.isEmpty {
            candidates.append(override)
        }

        let home = fileManager.homeDirectoryForCurrentUser.path
        candidates.append(contentsOf: [
            "\(home)/.homebrew/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex"
        ])

        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").map { "\($0)/codex" })
        }

        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }
}
