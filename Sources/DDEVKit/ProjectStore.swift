import Foundation
import Observation

@MainActor
@Observable
public final class ProjectStore {
    public private(set) var projects: [DDEVProject] = []
    public private(set) var busyProjects: Set<String> = []
    public private(set) var isRefreshing = false
    public private(set) var engine: EngineState = .down(reason: "not probed yet")
    public private(set) var engineKind: ContainerEngineKind = .unknown("")
    public private(set) var log: [String] = []
    public var lastError: String?

    /// Engine popover state (loaded on demand — it costs extra docker calls).
    public private(set) var engineDetails: EngineDetails?
    public private(set) var isLoadingEngineDetails = false

    /// Per-project detail popover state, keyed by project name.
    public private(set) var projectDetails: [String: ProjectDetails] = [:]
    public private(set) var loadingDetails: Set<String> = []
    public private(set) var detailErrors: [String: String] = [:]

    private let service: DDEVService
    private let engineProbe: EngineProbe
    private let containerEngine: ContainerEngineController
    private let inspector: DockerInspector?
    private var cachedVersionInfo: DDEVVersionInfo?
    private let logLimit = 50
    private let logDefaultsKey = "ddevManager.actionLog"
    private let defaults: UserDefaults

    public init(
        service: DDEVService,
        engineProbe: EngineProbe,
        containerEngine: ContainerEngineController,
        inspector: DockerInspector? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.engineProbe = engineProbe
        self.containerEngine = containerEngine
        self.inspector = inspector
        self.defaults = defaults
        self.log = defaults.stringArray(forKey: logDefaultsKey) ?? []
    }

    /// Whether the panel can offer a working "Start …" button for the detected backend
    /// (Colima, Docker Desktop, OrbStack, Rancher Desktop, or a best-effort Colima fallback).
    public var canStartEngine: Bool { containerEngine.canStart(kind: engineKind) }
    public var engineKindDisplayName: String { engineKind.displayName }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        engine = await engineProbe.probe()
        engineKind = await containerEngine.detectKind()
        do {
            projects = try await service.list()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func start(_ name: String) async { await perform(name, label: "start \(name)") { try await service.start(name) } }
    public func stop(_ name: String) async { await perform(name, label: "stop \(name)") { try await service.stop(name) } }
    public func restart(_ name: String) async { await perform(name, label: "restart \(name)") { try await service.restart(name) } }

    public func poweroffAll() async {
        await perform("__all__", label: "poweroff") { try await service.poweroff() }
    }

    public func startEngine() async {
        let kind = engineKind
        await perform("__engine__", label: "start \(kind.displayName)") { try await containerEngine.start(kind: kind) }
    }

    public func isBusy(_ name: String) -> Bool { busyProjects.contains(name) }

    // MARK: - On-demand detail loading

    public func isLoadingDetails(_ name: String) -> Bool { loadingDetails.contains(name) }

    /// Loads engine context/socket, ddev toolchain versions, and live container stats for the
    /// badge popover. Runs only when that popover is opened.
    public func loadEngineDetails() async {
        isLoadingEngineDetails = true
        defer { isLoadingEngineDetails = false }
        let context = await inspector?.contextInfo()
        let stats = await inspector?.stats() ?? []
        engineDetails = EngineDetails(
            state: engine,
            kind: engineKind,
            contextName: context?.name,
            socketPath: context?.socket,
            version: await versionInfo(),
            stats: stats
        )
    }

    /// Loads `ddev describe` plus the docker-side extras for one project's detail popover.
    public func loadDetails(for name: String) async {
        guard !loadingDetails.contains(name) else { return }
        loadingDetails.insert(name)
        defer { loadingDetails.remove(name) }
        do {
            let description = try await service.describe(name)
            let containers = await inspector?.containers(projectName: name) ?? []
            let stats = containers.contains(where: \.isRunning) ? await inspector?.stats() ?? [] : []
            let volumes = ProjectDetails.volumes(await inspector?.volumeUsage() ?? [], forProject: name)
            var drift: ImageDrift?
            if let expected = await versionInfo()?.expectedImageTag {
                drift = ImageDrift(expectedTag: expected, tagsByService: description.imageTagsByService)
            }
            projectDetails[name] = ProjectDetails(
                description: description,
                containers: containers.map { info in
                    ContainerDetail(info: info, stat: stats.first { $0.name == info.name })
                },
                volumes: volumes,
                drift: drift
            )
            detailErrors[name] = nil
        } catch {
            detailErrors[name] = error.localizedDescription
        }
    }

    /// `ddev version` output only changes when ddev itself is upgraded, so fetch it once.
    private func versionInfo() async -> DDEVVersionInfo? {
        if let cachedVersionInfo { return cachedVersionInfo }
        guard let info = try? await service.versionInfo() else { return nil }
        cachedVersionInfo = info
        return info
    }

    private func perform(_ name: String, label: String, _ action: () async throws -> Void) async {
        busyProjects.insert(name)
        defer { busyProjects.remove(name) }
        // Container state/uptime in a cached detail popover is stale after any action.
        projectDetails[name] = nil
        engineDetails = nil
        do {
            try await action()
            lastError = nil
            appendLog("✅ \(label) succeeded")
        } catch {
            lastError = error.localizedDescription
            appendLog("❌ \(label) failed: \(error.localizedDescription)")
        }
        await refresh()
    }

    private func appendLog(_ line: String) {
        log.append(line)
        if log.count > logLimit {
            log.removeFirst(log.count - logLimit)
        }
        defaults.set(log, forKey: logDefaultsKey)
    }
}
