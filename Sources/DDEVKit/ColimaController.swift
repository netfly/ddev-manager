import Foundation

/// Wraps `colima start`, used to bring the container engine back up from the panel.
public struct ColimaController: Sendable {
    private let runner: CommandRunner
    private let path: String?

    public init(runner: CommandRunner, path: String? = ColimaController.resolvePath()) {
        self.runner = runner
        self.path = path
    }

    public static func resolvePath() -> String? {
        ["/opt/homebrew/bin/colima", "/usr/local/bin/colima"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public var isAvailable: Bool { path != nil }

    public func start() async throws {
        guard let path else { throw DDEVError.cliNotFound }
        let result = try await runner.run(executable: path, arguments: ["start"], timeout: 300)
        guard result.succeeded else {
            throw DDEVError.commandFailed(
                command: "colima start",
                exitCode: result.exitCode,
                message: DDEVService.firstMeaningfulMessage(result)
            )
        }
    }
}
