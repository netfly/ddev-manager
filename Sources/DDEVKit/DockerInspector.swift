import Foundation

// MARK: - Values

/// One row of `docker stats --no-stream` (live CPU/memory for a running container).
public struct ContainerStat: Equatable, Sendable {
    public let name: String
    public let cpuPercent: Double?
    public let memoryBytes: Int64?
    public let memoryPercent: Double?
    public let memoryUsageText: String

    public init(name: String, cpuPercent: Double?, memoryBytes: Int64?, memoryPercent: Double?, memoryUsageText: String) {
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.memoryPercent = memoryPercent
        self.memoryUsageText = memoryUsageText
    }
}

/// Container state from `docker inspect` — uptime and restart count are not available from
/// ddev's own output, which only reports a coarse project-level status.
public struct ContainerInfo: Equatable, Sendable {
    public let name: String
    public let status: String          // running | exited | created | …
    public let health: String?         // healthy | starting | unhealthy | nil (no healthcheck)
    public let startedAt: Date?
    public let restartCount: Int
    public let image: String

    public init(name: String, status: String, health: String?, startedAt: Date?, restartCount: Int, image: String) {
        self.name = name
        self.status = status
        self.health = health
        self.startedAt = startedAt
        self.restartCount = restartCount
        self.image = image
    }

    public var isRunning: Bool { status == "running" }

    /// `ddev-t3test-web` → `web`, so the popover can show short service names.
    public func shortName(project: String) -> String {
        let prefix = "ddev-\(project)-"
        if name.hasPrefix(prefix) { return String(name.dropFirst(prefix.count)) }
        if name.lowercased().hasPrefix(prefix.lowercased()) { return String(name.dropFirst(prefix.count)) }
        return name
    }

    /// Seconds since the container started, only meaningful while it is running.
    public var uptime: TimeInterval? {
        guard isRunning, let startedAt else { return nil }
        return max(0, Date().timeIntervalSince(startedAt))
    }
}

/// One volume row of `docker system df -v`, with the compose project label ddev sets so
/// volumes can be attributed to a project without guessing from the name.
public struct VolumeUsage: Equatable, Sendable {
    public let name: String
    public let sizeText: String
    public let bytes: Int64?
    public let composeProject: String?
    public let links: Int

    public init(name: String, sizeText: String, bytes: Int64?, composeProject: String?, links: Int) {
        self.name = name
        self.sizeText = sizeText
        self.bytes = bytes
        self.composeProject = composeProject
        self.links = links
    }

    /// Mutagen sync volumes are a regenerable cache, worth showing separately from real data.
    public var isMutagenCache: Bool { name.hasSuffix("_project_mutagen") }
}

// MARK: - Size parsing

public enum DockerSize {
    private static let units: [(String, Double)] = [
        ("tib", 1_099_511_627_776), ("gib", 1_073_741_824), ("mib", 1_048_576), ("kib", 1024),
        ("tb", 1_000_000_000_000), ("gb", 1_000_000_000), ("mb", 1_000_000), ("kb", 1000),
        ("b", 1),
    ]

    /// `164.7MB`, `96.1MiB`, `28.67kB`, `0B` → bytes. Docker mixes decimal (`MB`) and binary
    /// (`MiB`) units across commands, so both spellings must be handled.
    public static func bytes(from text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, trimmed != "n/a" else { return nil }
        let digits = trimmed.prefix { $0.isNumber || $0 == "." }
        guard let value = Double(digits) else { return nil }
        let unit = trimmed.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        guard let match = units.first(where: { unit == $0.0 }) else {
            return unit.isEmpty ? Int64(value) : nil
        }
        return Int64(value * match.1)
    }

    public static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Parsers

public enum DockerStatsParser {
    private struct Row: Decodable {
        let Name: String
        let CPUPerc: String
        let MemUsage: String
        let MemPerc: String
    }

    /// `docker stats --no-stream --format '{{json .}}'` → one JSON object per line.
    public static func parse(_ output: String) -> [ContainerStat] {
        let decoder = JSONDecoder()
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            guard let data = line.data(using: .utf8),
                  let row = try? decoder.decode(Row.self, from: data) else { return nil }
            return ContainerStat(
                name: row.Name,
                cpuPercent: percent(row.CPUPerc),
                memoryBytes: DockerSize.bytes(from: row.MemUsage.split(separator: "/").first.map(String.init) ?? ""),
                memoryPercent: percent(row.MemPerc),
                memoryUsageText: row.MemUsage
            )
        }
    }

    static func percent(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
    }
}

public enum DockerInspectParser {
    /// Parses the pipe-separated `docker inspect --format` output used by `DockerInspector`:
    /// `/name|status|health|startedAt|restartCount|image`
    public static func parse(_ output: String) -> [ContainerInfo] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()

        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 6 else { return nil }
            let health = parts[2] == "none" || parts[2].isEmpty ? nil : parts[2]
            return ContainerInfo(
                name: parts[0].hasPrefix("/") ? String(parts[0].dropFirst()) : parts[0],
                status: parts[1],
                health: health,
                startedAt: formatter.date(from: parts[3]) ?? plain.date(from: parts[3]),
                restartCount: Int(parts[4]) ?? 0,
                image: parts[5]
            )
        }
    }
}

public enum DockerVolumeParser {
    private struct Row: Decodable {
        let Name: String
        let Size: String
        let Labels: String?
        let Links: String?
    }

    /// `docker system df -v --format '{{json .Volumes}}'` → a JSON array; `Labels` is a flat
    /// `k=v,k=v` string, not an object.
    public static func parse(_ output: String) -> [VolumeUsage] {
        guard let data = output.data(using: .utf8),
              let rows = try? JSONDecoder().decode([Row].self, from: data) else { return [] }
        return rows.map { row in
            VolumeUsage(
                name: row.Name,
                sizeText: row.Size,
                bytes: DockerSize.bytes(from: row.Size),
                composeProject: label(row.Labels, key: "com.docker.compose.project"),
                links: Int(row.Links ?? "0") ?? 0
            )
        }
    }

    static func label(_ labels: String?, key: String) -> String? {
        guard let labels else { return nil }
        for pair in labels.split(separator: ",") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2, kv[0] == key { return kv[1] }
        }
        return nil
    }
}

// MARK: - Inspector

/// Reads the extra docker-side facts the panel shows (context/socket, live stats, per-project
/// container state, volume sizes). Deliberately tolerant: every method degrades to nil/empty
/// instead of throwing, because these are informational extras — the panel must keep working
/// when the engine is down or an older docker CLI lacks a flag.
public struct DockerInspector: Sendable {
    private let runner: CommandRunner
    private let dockerPath: String?

    public init(runner: CommandRunner, dockerPath: String? = EngineProbe.resolveDocker()) {
        self.runner = runner
        self.dockerPath = dockerPath
    }

    public var isAvailable: Bool { dockerPath != nil }

    private func docker(_ args: [String], timeout: TimeInterval) async -> CommandResult? {
        guard let dockerPath else { return nil }
        guard let result = try? await runner.run(executable: dockerPath, arguments: args, timeout: timeout),
              result.succeeded else { return nil }
        return result
    }

    /// Active context name + its docker endpoint (the socket path), which identifies *which*
    /// backend is answering — Colima's socket lives under `~/.colima`, OrbStack's under
    /// `~/.orbstack`, and so on. Readable even while the daemon is down.
    public func contextInfo() async -> (name: String, socket: String)? {
        guard let result = await docker(
            ["context", "inspect", "--format", "{{.Name}}|{{.Endpoints.docker.Host}}"],
            timeout: 10
        ) else { return nil }
        let parts = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard let name = parts.first, !name.isEmpty else { return nil }
        return (name, parts.count > 1 ? parts[1] : "")
    }

    public func stats() async -> [ContainerStat] {
        guard let result = await docker(["stats", "--no-stream", "--format", "{{json .}}"], timeout: 20) else { return [] }
        return DockerStatsParser.parse(result.stdout)
    }

    /// Containers belonging to one ddev project, found via the `com.ddev.site-name` label
    /// ddev stamps on every container it creates (more reliable than matching names).
    public func containers(projectName: String) async -> [ContainerInfo] {
        guard let listed = await docker(
            ["ps", "-a", "--filter", "label=com.ddev.site-name=\(projectName)", "--format", "{{.Names}}"],
            timeout: 15
        ) else { return [] }
        let names = listed.stdout.split(whereSeparator: \.isNewline).map(String.init)
        guard !names.isEmpty else { return [] }
        let format = "{{.Name}}|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}"
            + "|{{.State.StartedAt}}|{{.RestartCount}}|{{.Config.Image}}"
        guard let inspected = await docker(["inspect", "--format", format] + names, timeout: 20) else { return [] }
        return DockerInspectParser.parse(inspected.stdout)
    }

    public func volumeUsage() async -> [VolumeUsage] {
        guard let result = await docker(["system", "df", "-v", "--format", "{{json .Volumes}}"], timeout: 30) else { return [] }
        return DockerVolumeParser.parse(result.stdout)
    }
}
