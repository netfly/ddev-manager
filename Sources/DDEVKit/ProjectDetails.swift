import Foundation

/// A container plus its live stats row (nil while the container isn't running).
public struct ContainerDetail: Equatable, Sendable {
    public let info: ContainerInfo
    public let stat: ContainerStat?

    public init(info: ContainerInfo, stat: ContainerStat?) {
        self.info = info
        self.stat = stat
    }
}

/// Image-tag drift: the project's configured ddev images vs. the tag the installed ddev
/// would use. A mismatch means the project still carries containers/images from an older
/// ddev release and wants a `ddev restart` (or `ddev debug rebuild`).
public struct ImageDrift: Equatable, Sendable {
    public let expectedTag: String
    public let tagsByService: [String: String]

    public init(expectedTag: String, tagsByService: [String: String]) {
        self.expectedTag = expectedTag
        self.tagsByService = tagsByService
    }

    public var outdatedServices: [String] {
        tagsByService.filter { $0.value != expectedTag }.keys.sorted()
    }

    public var isDrifting: Bool { !outdatedServices.isEmpty }
}

/// Everything the per-project detail popover shows, assembled from `ddev describe` plus a
/// few docker reads. Built on demand only.
public struct ProjectDetails: Equatable, Sendable {
    public let description: DDEVProjectDescription
    public let containers: [ContainerDetail]
    public let volumes: [VolumeUsage]
    public let drift: ImageDrift?

    public init(
        description: DDEVProjectDescription,
        containers: [ContainerDetail],
        volumes: [VolumeUsage],
        drift: ImageDrift?
    ) {
        self.description = description
        self.containers = containers
        self.volumes = volumes
        self.drift = drift
    }

    /// Real project data (database etc.), excluding regenerable mutagen sync caches.
    public var dataBytes: Int64 {
        volumes.filter { !$0.isMutagenCache }.compactMap(\.bytes).reduce(0, +)
    }

    public var cacheBytes: Int64 {
        volumes.filter(\.isMutagenCache).compactMap(\.bytes).reduce(0, +)
    }

    public var totalBytes: Int64 { dataBytes + cacheBytes }

    /// Volumes carry `com.docker.compose.project=ddev-<lowercased project name>`; the name
    /// itself can be mixed case (`ES-Consulting`), so match case-insensitively and fall back
    /// to a name prefix for volumes created by older ddev versions without the label.
    public static func volumes(_ all: [VolumeUsage], forProject name: String) -> [VolumeUsage] {
        let expected = "ddev-\(name)".lowercased()
        return all.filter { volume in
            if let project = volume.composeProject?.lowercased() { return project == expected }
            let lower = volume.name.lowercased(), prefix = name.lowercased()
            return lower.hasPrefix("\(prefix)-") || lower.hasPrefix("\(prefix)_")
        }
        .sorted { $0.name < $1.name }
    }
}

/// Engine-level facts for the badge popover: which backend is actually answering, the ddev
/// toolchain versions, and live resource use across all containers.
public struct EngineDetails: Equatable, Sendable {
    public let state: EngineState
    public let kind: ContainerEngineKind
    public let contextName: String?
    public let socketPath: String?
    public let version: DDEVVersionInfo?
    public let stats: [ContainerStat]

    public init(
        state: EngineState,
        kind: ContainerEngineKind,
        contextName: String?,
        socketPath: String?,
        version: DDEVVersionInfo?,
        stats: [ContainerStat]
    ) {
        self.state = state
        self.kind = kind
        self.contextName = contextName
        self.socketPath = socketPath
        self.version = version
        self.stats = stats
    }

    public var serverVersion: String? {
        if case .running(let version) = state { return version }
        return nil
    }

    public var runningContainerCount: Int { stats.count }

    public var totalCPUPercent: Double { stats.compactMap(\.cpuPercent).reduce(0, +) }

    public var totalMemoryBytes: Int64 { stats.compactMap(\.memoryBytes).reduce(0, +) }
}
