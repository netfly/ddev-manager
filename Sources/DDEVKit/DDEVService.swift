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

    /// The resolved `ddev` binary, needed by callers that have to spell the command out for an
    /// external process (e.g. a terminal app running `ddev ssh`, which can't rely on the GUI PATH).
    public var executable: String { executablePath }

    /// First existing candidate, honouring a user override.
    public static func resolveExecutable(override: String?) -> String? {
        let candidates = [override].compactMap { $0 }.filter { !$0.isEmpty } + defaultCandidatePaths
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func list() async throws -> [DDEVProject] {
        let result = try await exec(["list", "-j"], timeout: 30)
        return try DDEVListParser.parse(result.stdout)
    }

    /// One process per project — call only on demand (detail popover), never in list refresh.
    public func describe(_ name: String) async throws -> DDEVProjectDescription {
        let result = try await exec(["describe", name, "-j"], timeout: 60)
        return try DDEVDescribeParser.parse(result.stdout)
    }

    /// Toolchain versions; cheap but static, so the store caches the result.
    public func versionInfo() async throws -> DDEVVersionInfo {
        let result = try await exec(["version", "-j"], timeout: 30)
        return try DDEVVersionParser.parse(result.stdout)
    }

    public func start(_ name: String) async throws { _ = try await exec(["start", "-y", name], timeout: 300) }
    public func stop(_ name: String) async throws { _ = try await exec(["stop", name], timeout: 120) }
    public func restart(_ name: String) async throws { _ = try await exec(["restart", "-y", name], timeout: 300) }
    public func poweroff() async throws { _ = try await exec(["poweroff"], timeout: 180) }

    /// Runs a ddev *host* command (`sequelace`, `tableplus`, …) for a project. These commands
    /// resolve the project from the working directory via ddev's `DDEV_*` environment, not from
    /// an argument, so they must run with the project root as cwd — hence `/bin/sh -c` rather
    /// than invoking `ddev` directly.
    public func runHostCommand(_ subcommand: String, approot: String) async throws {
        let script = "cd \(ShellQuote.single(approot)) && exec "
            + "\(ShellQuote.single(executablePath)) \(ShellQuote.single(subcommand))"
        let result = try await runner.run(executable: "/bin/sh", arguments: ["-c", script], timeout: 120)
        guard result.succeeded else {
            throw DDEVError.commandFailed(
                command: "ddev \(subcommand)",
                exitCode: result.exitCode,
                message: Self.firstMeaningfulMessage(result)
            )
        }
    }

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
