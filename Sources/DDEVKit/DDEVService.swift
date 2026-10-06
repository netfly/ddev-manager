import Foundation

public struct DDEVService: Sendable {
    public static let defaultCandidatePaths = [
        "/opt/homebrew/bin/ddev",
        "/usr/local/bin/ddev",
        "/opt/local/bin/ddev"
    ]

    private let runner: CommandRunner
    private let executablePath: String

    public init(runner: CommandRunner, executablePath: String) {
        self.runner = runner
        self.executablePath = executablePath
    }

    /// First existing candidate, honouring a user override.
    public static func resolveExecutable(override: String?) -> String? {
        let candidates = [override].compactMap { $0 }.filter { !$0.isEmpty } + defaultCandidatePaths
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func list() async throws -> [DDEVProject] {
        let result = try await exec(["list", "-j"], timeout: 30)
        return try DDEVListParser.parse(result.stdout)
    }

    public func start(_ name: String) async throws { _ = try await exec(["start", "-y", name], timeout: 300) }
    public func stop(_ name: String) async throws { _ = try await exec(["stop", name], timeout: 120) }
    public func restart(_ name: String) async throws { _ = try await exec(["restart", "-y", name], timeout: 300) }
    public func poweroff() async throws { _ = try await exec(["poweroff"], timeout: 180) }

    @discardableResult
    private func exec(_ args: [String], timeout: TimeInterval) async throws -> CommandResult {
        let result = try await runner.run(executable: executablePath, arguments: args, timeout: timeout)
        guard result.succeeded else {
            throw DDEVError.commandFailed(
                command: "ddev " + args.joined(separator: " "),
                exitCode: result.exitCode,
                message: Self.firstMeaningfulMessage(result)
            )
        }
        return result
    }

    /// ddev writes JSON-lines logs; surface the `msg` of the last fatal/error record.
    static func firstMeaningfulMessage(_ result: CommandResult) -> String {
        let combined = (result.stderr + "\n" + result.stdout)
        var fallback = ""
        for line in combined.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let msg = obj["msg"] as? String else {
                if fallback.isEmpty, !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    fallback = String(line)
                }
                continue
            }
            let level = (obj["level"] as? String) ?? ""
            if level == "fatal" || level == "error" { return msg }
            if fallback.isEmpty { fallback = msg }
        }
        return fallback.isEmpty ? "unknown error" : fallback
    }
}
