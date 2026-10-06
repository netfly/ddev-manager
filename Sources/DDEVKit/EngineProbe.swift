import Foundation

public enum EngineState: Equatable, Sendable {
    case running(version: String)
    case down(reason: String)
    case dockerMissing
}

public struct EngineProbe: Sendable {
    private let runner: CommandRunner
    private let dockerPath: String?

    public init(runner: CommandRunner, dockerPath: String? = EngineProbe.resolveDocker()) {
        self.runner = runner
        self.dockerPath = dockerPath
    }

    public static func resolveDocker() -> String? {
        ["/opt/homebrew/bin/docker", "/usr/local/bin/docker"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func probe() async -> EngineState {
        guard let dockerPath else { return .dockerMissing }
        do {
            let r = try await runner.run(
                executable: dockerPath,
                arguments: ["version", "--format", "{{.Server.Version}}"],
                timeout: 10
            )
            let version = r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return r.succeeded && !version.isEmpty
                ? .running(version: version)
                : .down(reason: r.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Docker daemon not reachable" : r.stderr)
        } catch {
            return .down(reason: error.localizedDescription)
        }
    }
}
