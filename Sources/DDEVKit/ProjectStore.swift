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

    /// Last successfully fetched ddev release (persisted, so it survives restarts).
    public private(set) var latestRelease: DDEVRelease?

    private let service: DDEVService
    private let engineProbe: EngineProbe
    private let containerEngine: ContainerEngineController
    private let inspector: DockerInspector?
    private var cachedVersionInfo: DDEVVersionInfo?
    private let logLimit = 50
    private let logDefaultsKey = "ddevManager.actionLog"
    private let defaults: UserDefaults
    private let fetchLatestRelease: DDEVRelease.Fetcher?
    private let now: @Sendable () -> Date
    private let updateCheckedAtKey = "ddevManager.updateCheck.checkedAt"
    private let latestTagKey = "ddevManager.updateCheck.latestTag"
    private let latestURLKey = "ddevManager.updateCheck.latestURL"
    /// The running background update check, if any (internal so tests can await it).
    @ObservationIgnored private(set) var updateCheckTask: Task<Void, Never>?
    /// After a failed check, wait an hour before retrying (refresh runs every few seconds; GitHub allows 60 calls/h).
    @ObservationIgnored private var updateRetryAfter: Date?

    public init(
        service: DDEVService,
        engineProbe: EngineProbe,
        containerEngine: ContainerEngineController,
        inspector: DockerInspector? = nil,
        defaults: UserDefaults = .standard,
        fetchLatestRelease: DDEVRelease.Fetcher? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.service = service
        self.engineProbe = engineProbe
        self.containerEngine = containerEngine
        self.inspector = inspector
        self.defaults = defaults
        self.log = defaults.stringArray(forKey: logDefaultsKey) ?? []
        self.fetchLatestRelease = fetchLatestRelease
        self.now = now
        if let tag = defaults.string(forKey: latestTagKey), let url = defaults.string(forKey: latestURLKey) {
            latestRelease = DDEVRelease(tagName: tag, htmlURL: url)
        }
    }

    /// The installed ddev version, once `ddev version` has been read.
    public var installedDDEVVersion: String? { cachedVersionInfo?.ddevVersion }

    /// The newer release to advertise in the panel, or nil when up to date / unknown.
    public var availableUpdate: DDEVRelease? {
        guard let latestRelease, let installed = installedDDEVVersion,
              DDEVRelease.isNewer(latestRelease.tagName, than: installed) else { return nil }
        return latestRelease
    }

    /// Whether the panel can offer a working "Start …" button for the detected backend
    /// (Colima, Docker Desktop, OrbStack, Rancher Desktop, or a best-effort Colima fallback).
    public var canStartEngine: Bool { containerEngine.canStart(kind: engineKind) }
    public var engineKindDisplayName: String { engineKind.displayName }

    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        startUpdateCheckIfDue()
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

    /// The resolved `ddev` path, for actions the app layer has to launch itself (terminal).
    public var ddevExecutablePath: String { service.executable }

    /// Launches an on-host database GUI through ddev's own host command for that client.
    public func openDatabaseClient(_ client: DatabaseClient, project: DDEVProject) async {
        await perform(project.name, label: "\(client.displayName) for \(project.name)") {
            try await service.runHostCommand(client.ddevCommand, approot: project.approot)
        }
    }

    /// Records an action the app layer performed itself (e.g. opening a terminal), so successes
    /// and failures land in the same log as the ddev actions.
    public func recordExternalAction(label: String, failure: String? = nil) {
        if let failure {
            lastError = failure
            appendLog("❌ \(label) failed: \(failure)")
        } else {
            appendLog("✅ \(label) succeeded")
        }
    }

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

    /// Fetches the latest ddev release at most once per 24 h, in the background so refresh is
    /// never blocked. Failures are silent and leave the timestamp alone, so a refresh an hour later retries.
    private func startUpdateCheckIfDue() {
        guard let fetchLatestRelease, updateCheckTask == nil else { return }
        let checkedAt = defaults.object(forKey: updateCheckedAtKey) as? Date
        let due = (checkedAt.map { now().timeIntervalSince($0) >= 24 * 60 * 60 } ?? true)
            && (updateRetryAfter.map { now() >= $0 } ?? true)
        // Even when not due, the installed version is needed to judge the persisted release.
        guard due || cachedVersionInfo == nil else { return }
        updateCheckTask = Task {
            defer { updateCheckTask = nil }
            _ = await versionInfo()
            guard due else { return }
            guard let release = try? await fetchLatestRelease() else {
                updateRetryAfter = now().addingTimeInterval(60 * 60)
                return
            }
            updateRetryAfter = nil
            latestRelease = release
            defaults.set(release.tagName, forKey: latestTagKey)
            defaults.set(release.htmlURL, forKey: latestURLKey)
            defaults.set(now(), forKey: updateCheckedAtKey)
        }
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
