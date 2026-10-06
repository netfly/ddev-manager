import Foundation

/// Which Docker-compatible backend is currently active. Each of these tools sets its own
/// `docker context` name when it becomes the active engine, which is the most reliable
/// signal — `ddev` itself only cares that `docker version` succeeds, not which backend
/// answers it, so this is purely to offer the right "start it" action in the UI.
public enum ContainerEngineKind: Equatable, Hashable, Sendable {
    case colima
    case dockerDesktop
    case orbStack
    case rancherDesktop
    case podman
    case unknown(String)

    public var displayName: String {
        switch self {
        case .colima: "Colima"
        case .dockerDesktop: "Docker Desktop"
        case .orbStack: "OrbStack"
        case .rancherDesktop: "Rancher Desktop"
        case .podman: "Podman"
        case .unknown(let name): name.isEmpty ? "the container engine" : name
        }
    }

    public static func from(contextName: String) -> ContainerEngineKind {
        let n = contextName.lowercased()
        if n.contains("colima") { return .colima }
        if n.contains("orbstack") { return .orbStack }
        if n.contains("rancher") { return .rancherDesktop }
        if n.contains("desktop-linux") || n.contains("docker-desktop") { return .dockerDesktop }
        if n.contains("podman") { return .podman }
        return .unknown(contextName)
    }
}

/// Detects which container backend is active and knows how to start each one, so the panel
/// can offer a working "Start …" button no matter whether the user runs Colima, Docker
/// Desktop, OrbStack, Rancher Desktop, or (best-effort) Podman.
public struct ContainerEngineController: Sendable {
    private let runner: CommandRunner
    private let dockerPath: String?
    private let colimaPath: String?

    public init(
        runner: CommandRunner,
        dockerPath: String? = EngineProbe.resolveDocker(),
        colimaPath: String? = ContainerEngineController.resolveColima()
    ) {
        self.runner = runner
        self.dockerPath = dockerPath
        self.colimaPath = colimaPath
    }

    public static func resolveColima() -> String? {
        ["/opt/homebrew/bin/colima", "/usr/local/bin/colima"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static let appCandidates: [ContainerEngineKind: String] = [
        .dockerDesktop: "/Applications/Docker.app",
        .orbStack: "/Applications/OrbStack.app",
        .rancherDesktop: "/Applications/Rancher Desktop.app",
    ]

    /// Reads the active `docker context` (works even while the daemon itself is down — it's
    /// just reading local config) and falls back to guessing from what's installed.
    public func detectKind() async -> ContainerEngineKind {
        if let dockerPath,
           let result = try? await runner.run(executable: dockerPath, arguments: ["context", "show"], timeout: 5),
           result.succeeded {
            let name = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return .from(contextName: name) }
        }
        return Self.guessInstalledKind(colimaPath: colimaPath)
    }

    /// Fallback guess (e.g. docker itself isn't on PATH yet) from what's actually installed,
    /// in a rough order of "most likely to be what a ddev user has."
    public static func guessInstalledKind(colimaPath: String?) -> ContainerEngineKind {
        if colimaPath != nil { return .colima }
        for (kind, appPath) in appCandidates where FileManager.default.fileExists(atPath: appPath) {
            return kind
        }
        return .unknown("")
    }

    public func canStart(kind: ContainerEngineKind) -> Bool {
        switch kind {
        case .colima: colimaPath != nil
        case .dockerDesktop, .orbStack, .rancherDesktop:
            FileManager.default.fileExists(atPath: Self.appCandidates[kind] ?? "")
        case .podman, .unknown: colimaPath != nil
        }
    }

    public func start(kind: ContainerEngineKind) async throws {
        switch kind {
        case .colima, .podman, .unknown:
            guard let colimaPath else { throw DDEVError.cliNotFound }
            let result = try await runner.run(executable: colimaPath, arguments: ["start"], timeout: 300)
            try Self.throwIfFailed(result, command: "colima start")
        case .dockerDesktop, .orbStack, .rancherDesktop:
            guard let appPath = Self.appCandidates[kind], FileManager.default.fileExists(atPath: appPath) else {
                throw DDEVError.cliNotFound
            }
            let result = try await runner.run(executable: "/usr/bin/open", arguments: ["-a", appPath], timeout: 30)
            try Self.throwIfFailed(result, command: "open \(appPath)")
        }
    }

    private static func throwIfFailed(_ result: CommandResult, command: String) throws {
        guard result.succeeded else {
            throw DDEVError.commandFailed(
                command: command,
                exitCode: result.exitCode,
                message: DDEVService.firstMeaningfulMessage(result)
            )
        }
    }
}
